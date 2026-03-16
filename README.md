# Nudge

A personal productivity and lifestyle tracker for Android. Dark, minimal aesthetic. Everything stored locally — cloud backup is optional and end-to-end encrypted.

---

## Features

### Gym
- Log workouts (exercises, sets, reps, weight)
- Custom exercise library + built-in exercises
- Workout routines — save and reuse
- Weigh-in tracking with history
- Weekly streak (configurable target days/week)
- 3-tab layout: Today / Weekly / Logbook
- Per-exercise AI Coach stubs (target + rank — future)

### Finance
- Log expenses by category
- Monthly budget
- Spending vs budget progress
- Revolut auto-import via notification listener

### Food
- Log food entries with calories
- Personal food library
- Daily calorie total

### Habits
- Counter-based habit logging
- Daily completion tracking
- Streak tracking
- PIN / biometric lock (protected box)

### Books & Movies
- Watchlist / reading list management
- Status tracking (to-watch, watching, finished)

### Pomodoro / Focus
- Configurable work/break timers (default 50/17 min)
- Project-based session tracking
- App blocker during sessions
- Dedicated stats screen (total focus time, per-project breakdown, session history)

### Health
- Reads from Android Health Connect: steps, calories, heart rate, HRV, sleep, weight, hydration, blood pressure, body fat, oxygen saturation, exercise routes, and more
- Running coach with personal records and training data
- GPS route tracking

### Detox / Screen Time
- App usage tracking via UsageStatsManager
- App blocklist for Pomodoro mode

### AI
- Gemini integration (dual API key support)
- Markdown-rendered responses
- AI error log (last 50 entries)

---

## Home Screen Widgets

Five Android home screen widgets — long-press home screen → Widgets → search "nudge":

| Widget | Size | Content |
|--------|------|---------|
| GYM | 4×2 | Streak · sessions this week |
| FINANCE | 4×2 | Spent / budget · progress bar |
| HABITS | 4×2 | Done / total · progress bar |
| FOCUS | 2×2 | Focus time · sessions today |
| NUTRITION | 4×2 | Calories · progress to goal |

Widgets auto-refresh on app launch. All dark-themed to match the app.

---

## Cloud Backup

Optional. Requires Google Sign-In.

- Data is **AES-256-CBC encrypted on-device** before upload
- Your passphrase is the only decryption key — never stored anywhere
- Firestore stores only opaque encrypted blobs
- Each user's data is namespaced by Google UID
- Firestore security rules prevent cross-user access
- Signing out does **not** delete local data

Firestore layout:
```
users/{uid}/
  profile       ← display name, email, last seen (no sensitive data)
  backup/
    gym         ← { payload: "iv:ciphertext", backedUpAt, version }
    finance
    food
    food_library
    books
    movies
    settings
    protected
    pomodoro
```

---

## Tech Stack

| | |
|--|--|
| Framework | Flutter 3.29 (Dart ≥3.2) |
| Local storage | Hive 2.x (9 boxes) |
| State management | ChangeNotifier |
| Cloud | Firebase Auth + Firestore |
| AI | Gemini (`google_generative_ai`) |
| Charts | fl_chart |
| Font | Google Fonts — Outfit |
| Maps | Flutter Map (OpenStreetMap) |
| Location | geolocator |
| Health | Health Connect |
| Home widgets | home_widget |
| Notifications | flutter_local_notifications |
| Encryption | AES-256-CBC (`encrypt`) |
| QR / Barcode | mobile_scanner |
| PDF export | pdf + printing |

---

## Project Structure

```
lib/
├── app.dart                          ← NudgeTokens design system + app root
├── main.dart
├── storage.dart                      ← AppStorage (all Hive boxes)
├── models/
│   └── card_model.dart
├── providers/
│   └── app_state.dart                ← ChangeNotifier
├── services/
│   ├── auth_service.dart             ← Google Sign-In wrapper
│   ├── firebase_backup_service.dart  ← AES backup/restore
│   └── widget_service.dart           ← Home screen widget data push
├── screens/
│   ├── home_screen.dart              ← 2-column grid
│   ├── settings_screen.dart
│   ├── auth/
│   │   └── sign_in_screen.dart
│   ├── books/
│   ├── movies/
│   ├── gym/
│   │   └── gym_screen.dart
│   ├── pomodoro/
│   │   ├── pomodoro_screen.dart
│   │   └── pomodoro_stats_screen.dart
│   ├── protected/
│   │   ├── protected_habits_screen.dart
│   │   └── protected_gate.dart
│   ├── health/
│   │   └── running_coach_list_screen.dart
│   └── export/
├── utils/
│   ├── detox_service.dart
│   └── notification_service.dart
└── widgets/
    └── empty_card.dart

android/app/src/main/
├── kotlin/com/example/nudge/
│   ├── MainActivity.kt
│   ├── PomodoroBlockerService.kt     ← foreground app monitor
│   ├── RevolutNotificationService.kt ← Revolut expense parser
│   ├── GymWidget.kt
│   ├── FinanceWidget.kt
│   ├── HabitsWidget.kt
│   ├── PomodoroWidget.kt
│   └── FoodWidget.kt
└── res/
    ├── layout/                       ← widget_*.xml layouts
    ├── xml/                          ← widget_*_info.xml metadata
    └── drawable/                     ← widget_bg.xml, progress drawables
```

---

## Design System

All tokens in `abstract class NudgeTokens` in [lib/app.dart](lib/app.dart):

```dart
// Backgrounds
bg        = #050A0D
surface   = #0C1317
elevated  = #111B20
card      = #0F1A1F

// Accents
purple    = #7C4DFF
green     = #39D98A
amber     = #FFBF00
red       = #FF4D6A
blue      = #5AC8FA

// Text
textHigh  = #FFFFFF
textMid   = #B0C4CF
textLow   = #5A7582

// Borders
border    = white 8%
borderHi  = white 13%
```

Import anywhere: `import '../app.dart' show NudgeTokens;`

---

## Setup

### Requirements
- Flutter 3.29+
- Android SDK (minSdk 26 / Android 8.0, targetSdk 36)
- Java 11+

### Install
```bash
flutter pub get
flutter run --debug
```

### Firebase (optional — for cloud backup)
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an Android app with package name `com.example.nudge`
3. Add your debug SHA-1 fingerprint (required for Google Sign-In):
   ```powershell
   keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```
4. Download `google-services.json` → place at `android/app/google-services.json`
5. Enable **Google Sign-In** in Firebase Console → Authentication → Sign-in methods
6. Create a **Firestore** database and set these security rules:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{uid}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```

### Gemini AI
Add your Gemini API key in the app: Settings → AI → API Key

---

## Platform Notes

**Android only.** The following are Android-specific and will break an iOS build:
- `usage_stats` — requires `UsageStatsManager` (Android only)
- `installed_apps` — Android only
- `RevolutNotificationService` — `NotificationListenerService` (Android only)

---

## External Data Sources

- **Exercise Database**: [yuhonas/free-exercise-db](https://github.com/yuhonas/free-exercise-db) — Public Domain. Used for exercise thumbnails and instructions.

---

## Privacy

- All app data lives in Hive on your device
- Cloud backup is opt-in and requires explicit user action
- Backups are AES-256-CBC encrypted with your passphrase before leaving the device
- Google Sign-In provides only a stable UID for storage namespacing — no app content is shared with Google
- Signing out of Google does not delete or affect local data
