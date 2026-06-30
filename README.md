# Japan Driver

Flutter Web app for local Japanese driving-license question practice.

## Current Scope

- Web-first Flutter app; mobile and desktop code paths are kept reusable.
- Bundled local MUSASI scrape data from `scraped/`.
- Japanese UI with ruby/furigana rendering for question and explanation text.
- Local browser progress via `shared_preferences`.
- No account system, sync, question editing, or audio playback in v1.

The bundled scraped questions, images, and remote audio URLs are for private validation. Confirm content rights before any public release.

## Run

Flutter SDK was installed at:

```bash
/Users/remosama/development/flutter/bin/flutter
```

Run the Web app:

```bash
/Users/remosama/development/flutter/bin/flutter run -d chrome
```

Build the Web app:

```bash
/Users/remosama/development/flutter/bin/flutter build web
```

Serve a built release locally:

```bash
python3 -m http.server 8787 --directory build/web
```

## Verify

```bash
/Users/remosama/development/flutter/bin/flutter analyze
/Users/remosama/development/flutter/bin/flutter test
/Users/remosama/development/flutter/bin/flutter build web
```
