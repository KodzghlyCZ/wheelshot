# WheelShot

Guided Android camera app for inventory photos of **tires and rims** — built for flipping wheels on marketplaces like Bazoš.

Point, shoot, fill specs. Sessions land as folders with ordered photos + JSON/text specs ready for listing.

<p align="center">
  <img src="screenshots/capture-overall.png" alt="Capture overall shot" width="260" />
  <img src="screenshots/capture-guide.png" alt="On-screen capture guide" width="260" />
  <img src="screenshots/capture-landscape.png" alt="Landscape capture layout" width="260" />
</p>

## Features

- **Shoot modes** — wheel set, rims only, tires only, or spare
- **Guided wizard** — required angles with on-screen frames + tips (overall, tread, DOT, stamps, size, ET)
- **Torch for close-ups** — DOT / brand stamp steps auto-enable flash
- **Specs dials** — PCD, center bore, rim size/ET, tire width/aspect/Ø (T/R/ZR), DOT week/year, XL/RFT
- **Diameter sync** — set rim or tire Ø once; unset pieces pick up the same size
- **Tire catalog** — common combos from real listings; width/aspect cascade picks usual mates
- **Edit past shoots** — reopen sessions from home, retake photos, tweak specs
- **Yay / nay** — confirm or retake after each capture
- **Local storage** — `Documents/WheelShot/<session>/` (photos + `specs.json` / `specs.txt`)

## Install

### Download APK

Every push to `main` publishes a release APK. [Releases](https://github.com/KodzghlyCZ/wheelshot/releases/latest) opens that release with **wheelshot.apk** ready to download.

1. Open [the latest release](https://github.com/KodzghlyCZ/wheelshot/releases/latest)
2. Download `wheelshot.apk`
3. Install on Android (allow unknown sources if prompted)

### From source (USB)

```bash
git clone https://github.com/KodzghlyCZ/wheelshot.git
cd wheelshot
flutter pub get
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Or use the helper script (host Flutter + Android SDK):

```bash
./scripts/build-apk.sh
```

Needs USB debugging on a physical phone (Camera2). Emulators work poorly for this app.

## Flow

1. Pick category + session name + piece count  
2. Wizard walks required shots  
3. Fill rim/tire specs (dials or pencil manual entry)  
4. Photos + specs sit in the session folder for listing / tooling  

### Required shots

| Piece | Shots |
|-------|--------|
| Tire | overall, tread/surface, DOT close-up, size marking |
| Rim | overall, brand stamp, size (e.g. 18×7½J), ET/offset |

## Camera

Stills use the full sensor field of view (4:3 on a Pixel), the same frame as the system camera's photo mode. Focus locks on the shutter. Torch comes on for DOT/stamp close-ups.

Android Camera2 via `camera` + a vendored `camera_android` (`third_party/camera_android`). Upstream `ResolutionPreset.max` picks a CamcorderProfile video size, which on Pixel is a 16:9 center crop and looks zoomed in. The vendored plugin keeps that video profile for recording and, for stills, chooses the largest JPEG and preview sizes whose aspect matches the sensor.

## CI

[`.github/workflows/release-apk.yml`](.github/workflows/release-apk.yml) runs on every push to `main`/`master` (and on `v*` tags / manual dispatch):

1. Flutter `3.47.5` + JDK 17  
2. `flutter build apk --release`  
3. Upload `wheelshot.apk` artifact  
4. Publish a GitHub Release marked latest, with `wheelshot.apk` linked at the top  

Tag a version when you want a named release (`v1.2.0`) instead of `build-*`:

```bash
git tag v1.1.1
git push origin v1.1.1
```

## Project layout

```
lib/           Flutter app (screens, dials, session store)
assets/brand/  App branding
screenshots/   README captures
scripts/       Local build helpers
android/       Android host project
test/          Unit tests
```

## Non-goals

No OCR, cloud sync, photo editing, or iOS polish (yet).

## License

Private / all rights reserved unless otherwise noted.
