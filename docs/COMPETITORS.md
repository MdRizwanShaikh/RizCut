# RizCut vs top mobile video editors

Competitor columns follow the feature list you shared (VN, InShot, CapCut,
Premiere Rush, LumaFusion). ✅ = has it, — = not in that list. RizCut column
is what the app does today.

| Feature | RizCut | VN | InShot | CapCut | Rush | LumaFusion |
|---|---|---|---|---|---|---|
| Free, no watermark, no login needed | ✅ | ✅ | — | — | — | — |
| Multi-clip timeline, trim, split, speed | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Multi-track (layers / picture-in-picture) | ✅ | ✅ | — | — | ✅ | ✅ |
| Keyframe animation | ✅ position + opacity | ✅ | — | — | — | ✅ |
| Audio waveform on timeline | ✅ | ✅ | — | — | — | — |
| Export resolution + bitrate control | ✅ 480p–4K, 24/30/60 fps, 3 quality levels, size estimate | ✅ | — | — | ✅ | — |
| Canvas resize + background blur | ✅ 5 ratios, blur/colour | — | ✅ | — | — | — |
| Stickers | ✅ | — | ✅ | — | — | — |
| Music | ✅ your own files, sound from any video, pick the part that loops | — | ✅ trending | — | — | — |
| Sound effects | ✅ 6 built-in | — | — | — | — | — |
| Voiceover recording | ✅ | — | — | — | — | — |
| Advanced audio mixing | ✅ clip volume, music fade in/out, auto-duck under voiceover, layer sound, voiceover, SFX | — | — | — | — | ✅ |
| Green screen (chroma key) | ✅ green / blue | — | — | ✅ | — | — |
| Colour grading / filters | ✅ 8 presets + brightness/contrast/saturation, per layer | — | — | ✅ | — | — |
| Video stabilisation | ✅ | — | — | — | — | ✅ |
| Templates / ready layouts | ✅ 5 split-screen layouts, Shorts maker | — | — | ✅ | — | — |
| Trendy overlays / text | ✅ caption bands, text animations, transitions (8) | — | — | ✅ | — | — |
| Reverse, freeze frame | ✅ (Android) | — | — | — | — | — |
| Duet / reaction with camera | ✅ | — | — | — | — | — |
| Share to the app from other apps | ✅ | — | — | — | — | — |
| Hindi text (Devanagari) | ✅ Poppins font | — | — | — | — | — |
| Auto-captions | ❌ not yet | — | ✅ | ✅ | — | — |
| Background removal (AI) | ❌ not yet (green screen instead) | ✅ | — | — | — | — |
| Trending music library | ❌ (licensing) | — | ✅ | — | — | — |
| Cross-device editing | ⚠️ project backup only (media stays on phone) | ✅ Mac | — | — | ✅ | — |

## Not built yet, and why

- **Auto-captions** need speech-to-text. On-device options (e.g. Whisper) add a
  ~75 MB model download and native code; cloud options cost money per minute.
  This is the most valuable next feature. It needs a choice between these.
- **AI background removal** needs a segmentation model running on every
  frame. It's slow on mid-range phones. Green screen covers the common case today.
- **Trending music** requires licences from labels. Shipping popular songs
  without them would get the app removed from Play.
- **Pop / zoom text animation**: FFmpeg crashed when the overlay changes size
  every frame. Fade and slide animations are in.

## Only on the web preview

Camera, microphone, reverse and freeze frame need the Android app. The web
preview explains this where it applies.
