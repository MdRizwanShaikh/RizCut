# RizCut

Android video editor (Flutter + on-device FFmpeg). Original design, CapCut/InShot-style features.

- **Guest mode by default** — no login needed to edit or export.
- **Zero server cost for video** — all rendering happens on the phone.
- Optional login (Firebase Auth, free tier) planned only for project backup.
- AdMob planned only on the export step, 2–3 months after launch.

Full roadmap: [docs/PLAN.md](docs/PLAN.md)

## Current MVP
Import video → trim → export (480p / 720p / 1080p, 30/60 fps) → save to gallery / share.

## Structure
```
lib/
  core/                 theme, shared utils
  features/home/        guest-mode home
  features/editor/      preview + trim
  features/export/      export sheet (future AdMob hook)
  services/ffmpeg/      command builder (pure, tested) + on-device runner
```

FFmpeg uses `ffmpeg_kit_flutter_new_min` (LGPL build). Export tries the
Android hardware H.264 encoder first and falls back to software `mpeg4`.

## Develop
```bash
flutter pub get
flutter analyze && flutter test
flutter run
```
