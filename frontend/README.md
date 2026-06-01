# SnapCity Flutter MVP

SnapCity is a Flutter mobile prototype for an AI-powered civic action app. The app shows the core hackathon flow: Home impact dashboard -> Snap -> AI scan -> civic ticket -> reward -> case tracking.

## What Is Included

- Home / Impact dashboard
- Cases list with working filters
- Civic map prototype with issue pins, filters, route simulation, and case preview
- Feed with fixed / before-after / partner filters
- Camera flow: camera -> AI scan -> ticket bottom sheet -> reward -> case detail
- Shared mock cases across Home, Cases, Feed, Map, and Case Detail
- Backend contract models from the team PDF in `lib/backend_contract.dart`

## Flutter Entry Points

- `lib/main.dart` - app shell, screens, interaction flow
- `lib/mock_data.dart` - synthetic cases/issues used across the app
- `lib/models.dart` - UI data models
- `lib/widgets.dart` - shared cards, bottom navigation, feed/case rows, media
- `lib/snapcity_theme.dart` - colors and base theme
- `lib/backend_contract.dart` - FastAPI/Antigravity request and response mapping notes

## Backend Contract

The Flutter app will eventually POST to:

```text
/api/v1/report
```

Payload:

```json
{
  "report_id": "rep_10293",
  "image_url": "https://storage.mock/images/issue_01.jpg",
  "gps": { "lat": 24.9180, "lng": 67.0971 },
  "voice_note_transcript": "There is a deep open manhole..."
}
```

The response maps into ticket fields, AI reasoning, reward points, assigned responder, ETA, WhatsApp/email templates, and the case dashboard.

## Run

Install Flutter, then run:

```powershell
flutter pub get
flutter run
```

For a desktop browser preview with the mobile frame:

```powershell
flutter build web --debug
node flutter_web_server.mjs
```

Open `http://127.0.0.1:5175`.
