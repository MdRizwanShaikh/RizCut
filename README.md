# RizCut

Android video editor (Flutter + on-device FFmpeg). Original design, CapCut/InShot-style features.

- **Guest mode by default** — no login needed to edit or export.
- **Zero server cost for video** — all rendering happens on the phone.
- Optional login (Firebase Auth, free tier) only for backing up project edits.
- AdMob planned only on the export step, 2–3 months after launch.

Full roadmap: [docs/PLAN.md](docs/PLAN.md)

## Current features
- Import videos and photos (guest mode, no login), several at once; add more
  from the editor
- Canvas ratio (Original, 9:16, 1:1, 16:9, 4:5) with blurred or solid
  background
- Multi-clip timeline with centre playhead and scrubbing
- Split, delete, per-clip speed (0.25x–4x), undo/redo
- Trim handles on the selected clip, timeline zoom, arrange clips (drag to reorder)
- Edit clip/photo: rotate, flip, zoom-crop with pan, Ken Burns motion
  (zoom in/out, pan left/right)
- Filmstrip thumbnails on the timeline
- Stickers (built-in icon set, any colour), positioned and timed like text
- Text overlays: colour, size, background box, drag to position
- Filters: 8 presets + brightness / contrast / saturation (one colour matrix
  shared by preview and export)
- Transitions between clips: fade through black, flash white
- Audio: original sound volume/mute, background music (loops, fade in/out)
- Drafts auto-save on the device (no login) and reopen from Home
- Export 480p / 720p / 1080p at 30/60 fps → gallery + share
- Layers (video/photo on top, own filter and sound), split-screen layouts
  (2 stacked, 2 + caption, 3 stacked, side by side, PiP)
- Duet / reaction: reel below, record yourself with the camera (live filter)
  or import your own video on top
- Make a Short: any video → 15/30/60 s 9:16 highlights
- Transitions: fade black/white, pink flash, slide left/up, wipe, zoom;
  caption band text styles
- Share to RizCut from other apps (Android share sheet)
- Settings: optional Google/email sign-in, back up / restore drafts, delete
  account, privacy policy, licenses

## Web preview
`flutter build web --release --no-web-resources-cdn` builds a browser preview
with a bundled demo video (`web/demo.mp4`). Export is Android-only; on web the
export sheet explains that.

## Structure
```
lib/
  core/                 theme, shared utils
  features/home/        guest-mode home
  features/editor/      project model, timeline, text editor, preview
  features/export/      export sheet (future AdMob hook)
  services/ffmpeg/      command builder (pure, tested) + on-device runner
                        (exporter_io on Android, stub on web)
```

FFmpeg uses `ffmpeg_kit_flutter_new_min` (LGPL build). Export tries the
Android hardware H.264 encoder first and falls back to software `mpeg4`.

## Develop
```bash
flutter pub get
flutter analyze && flutter test
flutter run
```

## Release to Google Play
- Step-by-step guide: [docs/PLAY_STORE.md](docs/PLAY_STORE.md) (keystore, GitHub
  secrets, Play Console answers, store listing text)
- Release build: GitHub Actions → **Release (Play Store bundle)** → `app-release.aab`
- Optional login/backup: [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)
- Store graphics and screenshots: [docs/store/](docs/store/)
- Privacy policy page: [docs/privacy-policy.html](docs/privacy-policy.html)
  (publish with GitHub Pages from `/docs`)
