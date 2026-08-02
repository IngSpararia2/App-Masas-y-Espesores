# Branding resources

`app_icon_source.png` is an exact, byte-for-byte copy of the supplied 1024 x 1024 PNG named `App Laboratorista M.png`.

`splash_logo.png` is an exact, byte-for-byte copy of the supplied startup image named `App Labortorista.png`.

The files under `generated/` are deterministic size variants generated from those sources with Pillow 12.3.0. They are kept outside the native platform folders so `flutter create` cannot remove the canonical branding resources.

Run `python .\scripts\generate_branding.py` after replacing either source image.

Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\apply_branding.ps1` to copy the generated resources into the Android and Windows runners.

Icon source SHA-256: `99DAEDF5385C07F2D7A0867613D2FF8CC14CEDA886DC1844E51FA206DD5894A6`.

Splash source SHA-256: `E3EA035148272AA3DD3E7F7B85E834C6ADD2FD55A6455E86AC9A7143EF790DEC`.
