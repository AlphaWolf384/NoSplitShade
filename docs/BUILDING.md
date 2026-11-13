# Building No Split Shade: step by step (no experience needed)

> **Most people don't need to build anything.** If you just want the fix, download
> `NoSplitShade-vX.Y-magisk.zip` from the [Releases](../../../releases) page and
> follow **Install** in the [README](../README.md).
>
> Build it yourself only if you want to change something, such as adding a folder
> for a different device. See [Changing it](#changing-it) at the bottom.

Building runs one script that turns the text files in this repo into a ready-to-flash
Magisk zip. It takes about **15 minutes the first time** (mostly downloads) and
**under a minute** after that.

The build needs Linux. On Windows, you get Linux for free with **WSL**
(Windows Subsystem for Linux). Mac users: see the note at the end.

---

## Part 1: Windows only: install WSL (one time, ~5 min)

1. Click **Start**, type `PowerShell`, right-click **Windows PowerShell** and
   choose **Run as administrator**.
2. Paste this and press **Enter**:
   ```powershell
   wsl --install -d Ubuntu
   ```
3. **Restart your PC** when it asks.
4. After restart an **Ubuntu** window opens (or open **Ubuntu** from the Start menu).
   It asks you to make a **username** and **password**. Pick anything simple and
   remember the password. Nothing shows while you type it. That's normal.

You now have a Linux terminal. **Every command below goes in that Ubuntu window**, not PowerShell.

> **Tips for the Ubuntu window:**
> - Paste with **right-click** (Ctrl+V may not work).
> - Paste **one block at a time** and wait until the cursor (`$`) comes back before the next.
> - When it asks for your password, type the Ubuntu password from step 4 and press Enter.

---

## Part 2: Install the basic tools (one time, ~3 min)

```bash
sudo apt update
sudo apt install -y git unzip wget openjdk-17-jdk-headless
```

That installs:
- **git**: downloads this project
- **unzip / wget**: download and unpack files
- **Java 17**: required by Android's build tools

Check Java worked:
```bash
java -version
```
You should see something starting with `openjdk version "17`.

---

## Part 3: Download this project (one time)

```bash
cd ~
git clone https://github.com/<OWNER>/nosplitshade.git
cd nosplitshade
```

(Replace `<OWNER>/nosplitshade` with this repo's address. You can copy it from the
green **Code** button on GitHub.)

> **Don't** build from a Windows folder like `/mnt/c/Users/...`. Keep the project in
> your Linux home folder (`~`) as shown. Building from a Windows folder can break file
> permissions and line endings.

---

## Part 4: Download Android's build tools into the project (one time, ~5 min)

This puts Google's tools in a `tools/sdk` folder **inside the project**, where the
build script finds them automatically. Nothing else on your PC changes.

Paste this whole block:

```bash
mkdir -p tools/sdk/cmdline-tools
cd tools/sdk/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
unzip -q cmdline-tools.zip
mv cmdline-tools latest
rm cmdline-tools.zip
cd ~/nosplitshade
```

Now install the two pieces we need. `yes |` auto-accepts Google's license prompts:

```bash
yes | tools/sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=tools/sdk "build-tools;34.0.0" "platforms;android-33"
```

You'll see download progress. It's done when the `$` prompt comes back.

---

## Part 5: Build (every time, ~10 seconds)

```bash
cd ~/nosplitshade
chmod +x build.sh
./build.sh
```

The script prints a lot. **Success** ends with:

```
Done.
```

and lists files in `out/`. The one you want is:

```
out/NoSplitShade-v1.1-magisk.zip
```

---

## Part 6: Get the zip onto your PC / device

**On Windows:** open File Explorer and paste this in the address bar:

```
\\wsl$\Ubuntu\home
```

Open your username folder, then `nosplitshade` and `out`. Copy
`NoSplitShade-v1.1-magisk.zip` anywhere, such as your Desktop.

Or copy it to your Windows Downloads folder from the Ubuntu window:
```bash
cp out/NoSplitShade-*-magisk.zip /mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')/Downloads/
```

Then install it:
1. Copy the zip to the device (USB cable, SD card, or `adb push NoSplitShade-v1.1-magisk.zip /sdcard/Download/`).
2. On the device: **Magisk app → Modules → Install from storage →** pick the zip.
3. **Reboot.**

---

## Changing it

All edits are plain text files. Use any editor, such as Notepad via `\\wsl$\Ubuntu\home\<you>\nosplitshade`
or `nano` in Ubuntu.

| I want to... | Edit this | Then |
|---|---|---|
| Support a device whose SystemUI uses another folder (e.g. `sw360dp-land`) | Copy `res/values-land/` to `res/values-sw360dp-land/` (same `bools.xml`, keep `false`) | `./build.sh` |
| Change the version number | `VERSION` in `build.sh`, `versionCode`/`versionName` in `AndroidManifest.xml`, `version`/`versionCode` in `module/module.prop` | `./build.sh` |
| Change overlay priority | `android:priority` in `AndroidManifest.xml` | `./build.sh` |
| Change the module name/description | `module/module.prop` | `./build.sh` |

How to find which folders your device needs is under **Porting** in the [README](../README.md).

> **If you edit files in Notepad:** save with **LF** line endings for `.sh` and
> `module.prop` (Notepad: bottom-right shows `Windows (CRLF)`; click it and choose
> `Unix (LF)`). CRLF line endings in those files break the Magisk installer.

---

## Something went wrong?

| Message | What it means / fix |
|---|---|
| `wsl: command not found` / WSL won't install | Turn on virtualization in your PC's BIOS, or update Windows (WSL needs Windows 10 version 2004+ or Windows 11). |
| `sudo: ... incorrect password` | Use the Ubuntu password you created in Part 1, not your Windows password. |
| `error: JAVA_HOME not set and no JDK found` | Java isn't installed. Redo Part 2. |
| `error: ANDROID_SDK_ROOT / ANDROID_HOME not set and tools/sdk missing` | You're not in the project folder, or Part 4 didn't finish. Run `cd ~/nosplitshade` and redo Part 4. |
| `error: aapt2/zipalign/apksigner not found` or `missing .../android-33/android.jar` | The `sdkmanager` line in Part 4 didn't finish. Run it again. |
| `Permission denied` running `./build.sh` | Run `chmod +x build.sh` first. |
| `bash: ./build.sh: /usr/bin/env: 'bash\r'` | Windows line endings got in. Run `sed -i 's/\r$//' build.sh` and try again. |
| Module flashes but the shade is still split | Not a build problem. See **Troubleshooting** in the [README](../README.md). |

---

## Mac / Linux notes

- **Linux (Ubuntu/Debian):** skip Part 1 and follow Parts 2–5 as written.
- **macOS:** install Java 17 (`brew install openjdk@17`) and in Part 4 use the macOS
  download instead: `commandlinetools-mac-11076708_latest.zip`. Everything else is the same.
