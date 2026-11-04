# RizCut → Google Play: upload guide

Everything in the repo is ready for a release build. What's left needs **your** accounts
(keystore, GitHub secrets, Play Console). Follow the steps in order.

> Short version: create an upload key → add 4 GitHub secrets → run the **Release** workflow →
> download `app-release.aab` → upload it in Play Console with the texts and images below.

---

## 1. Upload key banao (one time)

Run this on your own computer (Java/Android Studio installed). **Keep the `.jks` file and
passwords safe forever.** If you lose them you can ask Google to reset the upload key, but
it's slow.

```bash
keytool -genkey -v -keystore ~/rizcut-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Convert it to text for GitHub:

```bash
base64 -w0 ~/rizcut-upload.jks > rizcut-upload.b64
```

(macOS: `base64 -i ~/rizcut-upload.jks -o rizcut-upload.b64`)

Local builds instead of CI: copy `android/key.properties.example` to
`android/key.properties` and fill it in. That file and `*.jks` are git-ignored.

## 2. GitHub secrets add karo

Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | contents of `rizcut-upload.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key password (same as keystore if you pressed Enter) |

Optional, only for login + cloud backup (see [FIREBASE_SETUP.md](FIREBASE_SETUP.md)):
`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`,
`FIREBASE_STORAGE_BUCKET`, `GOOGLE_SERVER_CLIENT_ID`. Without them the app ships with login
hidden — that's fine for the first release.

## 3. Release build banao

Repo → **Actions → Release (Play Store bundle) → Run workflow** (or push a tag like `v1.0.0`).
When it finishes, open the run → **Artifacts → rizcut-release** → download. Inside:

- `app-release.aab` → upload this to Play
- `app-release.apk` → install on your phone to test first

**Every new upload needs a higher build number.** In `pubspec.yaml`:
`version: 1.0.0+1` → next upload `1.0.1+2`, then `1.0.2+3`, …

## 4. Privacy policy ko public karo

Play needs a public URL. The page is in [`docs/privacy-policy.html`](privacy-policy.html).

Repo → **Settings → Pages → Build and deployment → Deploy from a branch** → branch with this
code (e.g. `main`), folder `/docs` → Save. After a minute it's live at:

`https://mdrizwanshaikh.github.io/RizCut/privacy-policy.html`

(The app's Settings → Privacy policy already opens this URL. If you host it elsewhere, build
with `--dart-define=PRIVACY_POLICY_URL=https://your-url`.)

## 5. Play Console

1. <https://play.google.com/console> → pay the one-time **$25** developer fee, verify identity.
2. **Create app** → name `RizCut - Video Editor`, default language English (or Hindi),
   App, Free.
3. **Test and release → Internal testing → Create release** → upload `app-release.aab`.
   Play App Signing: accept (recommended). Add your own email as a tester and install from the
   opt-in link.
4. Fill **App content** (left menu → *Policy → App content*) using the answers below.
5. Fill **Main store listing** with the texts and images below.
6. **Closed testing**: new personal developer accounts must run a closed test with at least
   **12 testers opted in for 14 days** before production access (check the current rule shown in
   your Console). Share the opt-in link with friends.
7. **Production → Create release** → same/newer `.aab` → roll out.

### App content answers

| Section | Answer |
|---|---|
| Privacy policy | the GitHub Pages URL above |
| App access | All functionality is available without special access (login is optional) |
| Ads | **No** (change to Yes when AdMob is added later) |
| Content rating | Questionnaire → category *All other app types*; answer **No** to violence, sexual content, profanity, drugs, gambling. User-generated content stays on device → no sharing between users. Expected: *Everyone / 3+* |
| Target audience | 13 and older (do not pick under-13 groups) |
| News app | No |
| Government app | No |
| Financial / health features | None |
| Data safety | see below |

### Data safety form

Only if you ship **with** Firebase login. Without it: *"No data collected"*, *"No data shared"*.

With login:

- **Does your app collect or share user data?** Yes, collected (not shared).
- **Encrypted in transit:** Yes. **Users can request deletion:** Yes (in-app: Settings → Account
  & backup → Delete account; and by email).
- Data types:
  - *Personal info → Email address* — collected, optional, purpose **Account management**.
  - *App activity → Other user-generated content* (project edit data in backups) — collected,
    optional, purpose **App functionality**.
- Photos/videos: **not collected** (editing happens on device; nothing is uploaded).
- Camera / microphone (Duet recording): used on device only → **not collected**.
- **Account deletion URL** (asked when the app has accounts): the privacy policy URL (it has a
  "Deleting your data" section).

### Store listing text

**App name** (≤30): `RizCut - Video Editor`

**Short description** (≤80):
`Edit videos & photos on your phone: trim, filters, music, text and stickers.`

**Full description:**

```
RizCut is a fast, simple video editor for your phone. No sign-up needed — open the app and start editing.

EDIT
• Trim, split, delete and rearrange clips
• Speed from 0.25x to 4x
• Mix videos and photos in one project
• Rotate, flip and zoom-crop any clip
• Ken Burns motion for photos: zoom in, zoom out, pan

LAYOUTS, DUETS & SHORTS
• Split-screen layouts: 2 stacked, 2 + caption band, 3 stacked, side by side, picture in picture
• Duet / reaction: a reel plays below while you record yourself on top, or import your own video
• Make a Short from any video: 15, 30 or 60 seconds of highlights in 9:16
• Layers: put a video or photo on top, move it, resize it, give it its own filter
• Share any video to RizCut from your gallery or other apps

STYLE
• 8 filters (Vivid, Neon, Warm, Cool, Vintage, Fade, B&W) plus brightness, contrast and saturation
• Text in any colour and size, with an optional background box
• Stickers you can place anywhere
• Transitions: fade, flash, slide, wipe and zoom
• News-style caption bands in yellow, white, black or pink
• Canvas for every app: 9:16, 1:1, 16:9, 4:5 with blurred or solid background

SOUND
• Add music from your phone, set volume, fade in and out
• Turn the original sound up, down or off

EXPORT
• 480p, 720p or 1080p at 30 or 60 fps
• Saved straight to your gallery and ready to share

PRIVATE BY DESIGN
• Your videos never leave your phone — all editing and exporting happens on the device
• Drafts save automatically on the phone
• Optional sign-in only if you want to back up your project edits
```

**Category:** Video Players & Editors. **Tags:** video editor, photo slideshow.
**Contact email:** your support email.

### Graphics (already in the repo)

| Play asset | File |
|---|---|
| App icon 512×512 | [`docs/store/icon-512.png`](store/icon-512.png) |
| Feature graphic 1024×500 | [`docs/store/feature-graphic-1024x500.png`](store/feature-graphic-1024x500.png) |
| Phone screenshots 1080×1920 | [`docs/store/screenshots/`](store/screenshots/) (5 images) |

The screenshots were taken from the web preview with the demo video. Replacing them with
screenshots from a real phone (your own footage) usually converts better.

---

## Before you press "Roll out" — checklist

- [ ] Installed `app-release.apk` on a real phone: import, edit, **export works and the video
      plays in the gallery** (this has not been tested on a device yet)
- [ ] Try at least one long video (2–5 min) at 1080p to check speed and memory
- [ ] Privacy policy URL opens
- [ ] Version code bumped if you uploaded before
- [ ] If Firebase is on: sign in, back up, restore, delete account all work

## Later: AdMob (2–3 months after launch)

Plan: show an ad only when the user exports. When you add it: add `google_mobile_ads`,
consent (UMP) for EU users, update the privacy policy's Advertising section, set **Ads: Yes**
in App content, and update the Data safety form (Device or other IDs → Advertising).
