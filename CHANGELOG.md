# Changelog

## v1.1 — 2026-11-13
- Added `values-sw392dp*` and `values-sw480dp*` overlay folders (default, `-land`, `-port`).
  GammaOS Next's SystemUI enables split shade in `sw392dp-land` and `sw480dp-land`,
  which v1.0 did not override. Fixes split shade on the Retroid Pocket Classic.
- Removed the `vendor_overlay_file` SELinux label from `customize.sh`; Magisk's
  default `system_file` context is correct for `/product/overlay`.

## v1.0 — 2026-11-13
- Initial release: static SystemUI RRO, priority 100, sets
  `config_use_split_notification_shade=false` in stock LOS20 qualifier folders.
