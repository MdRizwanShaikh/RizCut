# Firebase setup (optional login + cloud backup)

RizCut works fully without this. Do it only when you want **Settings → Account & backup**.
Cost: Firebase free tier (Spark). Auth is free up to 50,000 monthly users; backups are
small JSON documents (no videos), well inside Firestore's free quota.

## 1. Create the project
1. Open <https://console.firebase.google.com> → **Add project** → name it `rizcut`.
   Google Analytics is not needed.
2. **Build → Authentication → Get started**. Enable **Google** and **Email/Password**.
3. **Build → Firestore Database → Create database** (production mode, a region near your users).
4. In Firestore **Rules**, paste the contents of [`firestore.rules`](../firestore.rules) and publish.

## 2. Add the Android app
1. Project settings → **Add app → Android**. Package name: `com.rizcut.app`.
2. Add the **SHA-1** fingerprints:
   - your upload key: `keytool -list -v -keystore ~/rizcut-upload.jks -alias upload`
   - after the first Play upload: Play Console → **Test and release → App integrity →
     App signing** → copy the *App signing key* SHA-1 and add it too.
3. You don't need to add `google-services.json` to the repo. Instead copy these values
   from the downloaded `google-services.json`:

| dart-define | where in `google-services.json` |
|---|---|
| `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
| `FIREBASE_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
| `FIREBASE_PROJECT_ID` | `project_info.project_id` |
| `FIREBASE_SENDER_ID` | `project_info.project_number` |
| `FIREBASE_STORAGE_BUCKET` | `project_info.storage_bucket` |
| `GOOGLE_SERVER_CLIENT_ID` | the `oauth_client` entry with `"client_type": 3` → `client_id` |

## 3. Build with the values
```bash
flutter build appbundle --release \
  --dart-define=FIREBASE_API_KEY=xxx \
  --dart-define=FIREBASE_APP_ID=xxx \
  --dart-define=FIREBASE_PROJECT_ID=xxx \
  --dart-define=FIREBASE_SENDER_ID=xxx \
  --dart-define=FIREBASE_STORAGE_BUCKET=xxx \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
```
In GitHub Actions these come from repository secrets with the same names
(see [`.github/workflows/release.yml`](../.github/workflows/release.yml)).

If the values are missing the app builds and runs normally; Settings shows
"Cloud backup is off in this build".
