#!/usr/bin/env bash
# Rebuild the No Split Shade RRO APK and Magisk module.
# Looks for JDK + Android SDK (build-tools 34.0.0, platforms/android-33).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out"
BUILD="$ROOT/build"
KEYS="$ROOT/keys"
MODULE="$ROOT/module"

# Throwaway signing material only. build.sh creates a new keystore if missing.
KS="$KEYS/nosplitshade.keystore"
KS_ALIAS="nosplitshade"
# Password is local to this throwaway key; do not reuse it for anything real.
KS_PASS="android"

VERSION="v1.1"
APK_NAME="NoSplitShade.apk"
MAGISK_ZIP="$OUT/NoSplitShade-${VERSION}-magisk.zip"
SRC_ZIP="$OUT/NoSplitShade-${VERSION}-src.zip"

die() { echo "error: $*" >&2; exit 1; }

# --- locate tools ---
if [[ -z "${JAVA_HOME:-}" ]]; then
  if [[ -x "$ROOT/tools/jdk/bin/java" ]]; then
    export JAVA_HOME="$ROOT/tools/jdk"
  elif command -v java >/dev/null 2>&1; then
    # resolve JAVA_HOME from a java on PATH when possible
    java_bin="$(command -v java)"
    export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$java_bin" || echo "$java_bin")")")"
  fi
fi
[[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]] || die "JAVA_HOME not set and no JDK found"
export PATH="$JAVA_HOME/bin:$PATH"

if [[ -z "${ANDROID_SDK_ROOT:-}" ]]; then
  if [[ -d "$ROOT/tools/sdk" ]]; then
    export ANDROID_SDK_ROOT="$ROOT/tools/sdk"
  elif [[ -n "${ANDROID_HOME:-}" ]]; then
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
  fi
fi
[[ -n "${ANDROID_SDK_ROOT:-}" ]] || die "ANDROID_SDK_ROOT / ANDROID_HOME not set and tools/sdk missing"

BT=""
for cand in \
    "$ANDROID_SDK_ROOT/build-tools/34.0.0" \
    "$ANDROID_SDK_ROOT/build-tools/"*; do
  if [[ -x "${cand}/aapt2" && -x "${cand}/zipalign" && -x "${cand}/apksigner" ]]; then
    BT="$cand"
    break
  fi
done
[[ -n "$BT" ]] || die "aapt2/zipalign/apksigner not found under $ANDROID_SDK_ROOT/build-tools"

ANDROID_JAR="$ANDROID_SDK_ROOT/platforms/android-33/android.jar"
[[ -f "$ANDROID_JAR" ]] || die "missing $ANDROID_JAR (install platforms;android-33)"

AAPT2="$BT/aapt2"
ZIPALIGN="$BT/zipalign"
APKSIGNER="$BT/apksigner"

echo "JAVA_HOME=$JAVA_HOME"
echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
echo "build-tools=$BT"
"$AAPT2" version
java -version

rm -rf "$BUILD"
mkdir -p "$BUILD/compiled" "$BUILD/flat" "$OUT" "$KEYS"

# --- keystore (throwaway; generated if missing) ---
if [[ ! -f "$KS" ]]; then
  echo "Generating throwaway keystore at $KS"
  keytool -genkeypair -v \
    -keystore "$KS" \
    -alias "$KS_ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$KS_PASS" -keypass "$KS_PASS" \
    -dname "CN=NoSplitShade Throwaway, OU=Personal, O=Dom, L=Unknown, ST=Unknown, C=US"
fi

# --- compile + link RRO ---
echo "Compiling resources..."
# Compile each values file so qualifier directories are preserved.
while IFS= read -r -d '' xml; do
  "$AAPT2" compile "$xml" -o "$BUILD/flat/"
done < <(find "$ROOT/res" -type f -name '*.xml' -print0 | sort -z)

echo "Linking APK..."
# shellcheck disable=SC2046
"$AAPT2" link \
  --manifest "$ROOT/AndroidManifest.xml" \
  -I "$ANDROID_JAR" \
  --auto-add-overlay \
  --no-resource-deduping \
  --no-resource-removal \
  --min-sdk-version 33 \
  --target-sdk-version 33 \
  --version-code 1 \
  --version-name 1.0 \
  -o "$BUILD/NoSplitShade-unaligned.apk" \
  "$BUILD/flat/"*.flat

echo "zipalign..."
"$ZIPALIGN" -p -f 4 "$BUILD/NoSplitShade-unaligned.apk" "$BUILD/NoSplitShade-aligned.apk"

echo "Signing (v1+v2+v3)..."
"$APKSIGNER" sign \
  --ks "$KS" \
  --ks-key-alias "$KS_ALIAS" \
  --ks-pass "pass:$KS_PASS" \
  --key-pass "pass:$KS_PASS" \
  --v1-signing-enabled true \
  --v2-signing-enabled true \
  --v3-signing-enabled true \
  --min-sdk-version 24 \
  --out "$OUT/$APK_NAME" \
  "$BUILD/NoSplitShade-aligned.apk"

echo "Verifying APK..."
"$APKSIGNER" verify -v --print-certs "$OUT/$APK_NAME"
echo "======= apksigner verify --min-sdk-version 24 (reports v2+v3) ======="
"$APKSIGNER" verify -v --min-sdk-version 24 "$OUT/$APK_NAME"
echo "======= aapt2 dump xmltree AndroidManifest.xml ======="
"$AAPT2" dump xmltree "$OUT/$APK_NAME" --file AndroidManifest.xml
echo "======= aapt2 dump resources (bools) ======="
"$AAPT2" dump resources "$OUT/$APK_NAME"
echo "======= aapt dump --values resources (all configs) ======="
"$BT/aapt" dump --values resources "$OUT/$APK_NAME"

# --- Magisk module zip (files at archive root, LF + unix exec bit) ---
echo "Packaging Magisk zip..."
STAGE="$BUILD/magisk-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/system/product/overlay"
mkdir -p "$STAGE/META-INF/com/google/android"
cp "$OUT/$APK_NAME" "$STAGE/system/product/overlay/NoSplitShade.apk"
cp "$MODULE/module.prop" "$STAGE/module.prop"
cp "$MODULE/customize.sh" "$STAGE/customize.sh"
cp "$MODULE/META-INF/com/google/android/updater-script" "$STAGE/META-INF/com/google/android/updater-script"
cp "$MODULE/META-INF/com/google/android/update-binary" "$STAGE/META-INF/com/google/android/update-binary"
chmod 0755 "$STAGE/META-INF/com/google/android/update-binary"
# ensure LF endings on text module files
for f in "$STAGE/module.prop" "$STAGE/customize.sh" \
         "$STAGE/META-INF/com/google/android/updater-script" \
         "$STAGE/META-INF/com/google/android/update-binary"; do
  sed -i 's/\r$//' "$f"
done

python3 - "$STAGE" "$MAGISK_ZIP" << 'PY2'
import os, sys, zipfile
from pathlib import Path
stage = Path(sys.argv[1])
dest = Path(sys.argv[2])
if dest.exists():
    dest.unlink()

def mode_for(path: Path) -> int:
    if path.is_dir():
        return 0o40755
    name = path.as_posix()
    if path.name == "update-binary" and "META-INF" in name:
        return 0o100755
    if os.access(path, os.X_OK):
        return 0o100755
    return 0o100644

with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for p in sorted(stage.rglob("*")):
        rel = p.relative_to(stage).as_posix()
        data = b"" if p.is_dir() else p.read_bytes()
        info = zipfile.ZipInfo(rel + ("/" if p.is_dir() else ""))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.create_system = 3  # Unix
        info.external_attr = mode_for(p) << 16
        info.date_time = (2026, 1, 1, 0, 0, 0)
        zf.writestr(info, data)
print("wrote", dest)
PY2

echo "======= unzip -l magisk zip ======="
unzip -l "$MAGISK_ZIP"

# --- source bundle ---
echo "Packaging source zip..."
python3 - "$ROOT" "$SRC_ZIP" << 'PY2'
import sys, zipfile
from pathlib import Path
root = Path(sys.argv[1])
dest = Path(sys.argv[2])
if dest.exists():
    dest.unlink()
include = []
include.append(root / "AndroidManifest.xml")
include.append(root / "build.sh")
include.append(root / "README.md")
include += sorted((root / "res").rglob("*"))
include += sorted((root / "module").rglob("*"))
ks = root / "keys" / "nosplitshade.keystore"
if ks.is_file():
    include.append(ks)
# only files
files = [p for p in include if p.is_file()]
with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for p in files:
        rel = p.relative_to(root).as_posix()
        info = zipfile.ZipInfo(rel)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.create_system = 3
        mode = 0o100755 if p.name in ("build.sh", "update-binary") else 0o100644
        info.external_attr = mode << 16
        info.date_time = (2026, 1, 1, 0, 0, 0)
        data = p.read_bytes()
        if p.suffix in {".xml", ".sh", ".md", ".prop"} or p.name in {"update-binary", "updater-script", "customize.sh"}:
            data = data.replace(b"\r\n", b"\n")
        zf.writestr(info, data)
print("wrote", dest, "files:", len(files))
PY2

echo "======= outputs ======="
ls -l "$OUT/$APK_NAME" "$MAGISK_ZIP" "$SRC_ZIP"
echo "Done."
