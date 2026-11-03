# RizCut — Top-Level Plan (Android video editor, Flutter + FFmpeg)

## Context
Repo `MdRizwanShaikh/RizCut` abhi khaali hai (koi commit nahi). Goal: CapCut/InShot jaisi features wali **apni original design** ki video editing app (CapCut ka naam, logo, UI copy nahi karenge). Android pehle. App **bina login ke** poori chalni chahiye; login optional (sirf sync/backup jaisi cheezon ke liye), aur login ka kharcha/token load bahut kam. AdMob sirf **export/render ke time**, launch ke 2–3 mahine baad.

## Core decisions
- **Stack:** Flutter (Dart) + on-device FFmpeg. Saara editing/rendering phone pe hoga → server pe video kabhi nahi jayega → server cost ~₹0.
  - FFmpeg: original `ffmpeg_kit_flutter` 2025 mein retire ho gaya, isliye maintained fork `ffmpeg_kit_flutter_new` (LGPL/min build) use karenge; fallback: Android Media3 Transformer via platform channel (hardware encode, fast).
- **State mgmt:** Riverpod. **Local DB:** Isar/Drift (projects, drafts offline save).
- **Login (optional):** **Firebase Auth** — Google Sign-In + Email; free tier 50k MAU, alag server ki zaroorat nahi. Token: Firebase ID token (short JWT), app sirf tab bhejega jab cloud feature use ho → "low token" requirement poora.
  - Alternative agar Firebase na chahiye: Supabase free tier (50k MAU) — same cost, bas Postgres extra.
  - Phone OTP avoid (SMS paid hai).
- **Guest mode default:** app open → seedha editor, koi sign-up wall nahi. Login sirf Settings → "Backup projects" pe.

## Phases

### Phase 0 — Setup (Week 1)
- Flutter project `rizcut/`, package `com.rizcut.app`, folder structure: `lib/core`, `lib/features/{home,editor,export,auth,settings}`, `lib/services/{ffmpeg,storage,auth,ads}`.
- Lints, GitHub Actions CI (flutter analyze + test + debug APK build).

### Phase 1 — MVP Editor (Week 2–6)
- Gallery se video/photo import (multi-select), project create/save offline.
- Timeline: trim, split, delete, reorder, speed (0.25x–4x), volume, mute.
- Canvas ratio (9:16, 1:1, 16:9), background blur/color.
- Text overlay (fonts, color, position, timing), stickers (apne/free-license assets).
- Music: device audio + bundled royalty-free tracks; fade in/out.
- Filters (LUT based) + basic adjust (brightness/contrast/saturation).
- Transitions (fade, slide, zoom) between clips.
- Preview: `video_player` + overlay widgets (real-time); final render FFmpeg filtergraph se.
- **Export:** 480p/720p/1080p, 30/60fps, progress bar, cancel, gallery mein save, share.

### Phase 2 — Polish + Login (Week 7–9)
- Undo/redo, auto-save drafts, keyframe zoom (Ken Burns).
- Firebase Auth (Google) optional + Firestore/Storage mein sirf **project JSON** backup (videos nahi) → free tier mein rahega.
- Crashlytics + Analytics (free).
- Play Store internal testing → closed testing (12 testers × 14 din requirement) → production.

### Phase 3 — Growth features (Month 3+)
- Auto captions (on-device Whisper tiny / ML Kit), background remove (ML Kit selfie segmentation), templates, beat sync.

### Phase 4 — Monetization (launch ke 2–3 mahine baad)
- `google_mobile_ads`: **sirf export button pe** Rewarded/Interstitial ad (render shuru hone se pehle ya render ke dauraan). Editing ke time koi ad nahi.
- UMP consent (GDPR) + Play Data Safety form update.
- Optional later: "Remove ads / watermark" in-app purchase.

## Cost summary (monthly)
| Item | Cost |
|---|---|
| Firebase Auth (Google/Email) | ₹0 (≤50k MAU) |
| Firestore/Storage (project JSON only) | ₹0 (free quota) |
| Video rendering | ₹0 (on-device) |
| Play Console | $25 one-time |

## Repo structure (planned)
```
rizcut/
  android/  lib/  assets/{fonts,luts,music,stickers}  test/
  .github/workflows/ci.yml
  README.md  docs/PLAN.md
```

## First implementation step (approve hone ke baad)
1. Flutter project scaffold + folder structure + CI on branch `claude/gifted-carson-35xpo7`.
2. Guest-mode home screen + video import + simple trim + 720p export (end-to-end pipeline proof).
3. Commit + push.

## Verification
- `flutter analyze` aur `flutter test` pass.
- `flutter build apk --debug` CI mein green.
- Emulator/device pe: video import → trim → text add → 720p export → gallery mein play hota hai, bina login ke.
- Login flow: Google sign-in → project backup → reinstall → restore.
