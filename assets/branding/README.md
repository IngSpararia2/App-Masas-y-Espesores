# Branding resources

`app_icon_source.png` is an exact, byte-for-byte copy of the supplied 1024 x 1024 RGBA PNG.

The files under `generated/` are deterministic size variants generated from that source with Pillow 12.3.0. They are kept outside the native platform folders so `flutter create` cannot remove the canonical branding resources.

Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\apply_branding.ps1` to copy the generated resources into the Android and Windows runners.

Source SHA-256: `C908DC2887580525E9543216E6004F95AFDD62D041365EBAF43F52B5FB1C4115`.
