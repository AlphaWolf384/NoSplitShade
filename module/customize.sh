#!/system/bin/sh
# Optional Magisk installer hook. set_perm_recursive is provided by util_functions.sh.
ui_print "- No Split Shade: installing static SystemUI RRO (config_use_split_notification_shade=false)"
set_perm_recursive "$MODPATH/system" 0 0 0755 0644
ui_print "- Reboot, then check with: adb shell cmd overlay list | grep -i nosplitshade"
