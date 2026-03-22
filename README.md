# Nudge

A personal productivity and habit tracker built with Flutter for Android. Nudge integrates health data, AI-powered coaching, finance tracking, fitness planning, and daily habit management in one privacy-first app. All data is stored locally on device — cloud backup is optional and end-to-end encrypted.

---

## Overview

Nudge helps you build and maintain healthy routines across six life domains: **fitness**, **nutrition**, **finance**, **mental performance**, **entertainment**, and **mindfulness**. AI features use your own Gemini API key — nothing is sent to any server without your explicit consent.

---

## Features

### Fitness & Movement
- **Steps & Movement** — syncs step count, calories burned, and distance from Health Connect (Samsung Health, Pixel Health, Garmin, etc.)
- **Cardio Coach** — GPS-based activity tracking with real-time pace, distance, elevation, and heart rate. Supports Run, Walk, Hike, Cycle, and Trail Run. Keeps tracking in the background via a persistent foreground notification.
- **Gym** — log exercises, sets, weights, and reps. AI generates personalised workout routines. Tracks weekly volume and progression.
- **Body Composition** — track weight, body fat %, and muscle mass over time.

### Nutrition
- **Food & Nutrition** — log meals, track macros (protein, carbs, fat) and calories. AI nutrition coach analyses your logs.
- **Hydration** — track daily water intake with quick-add buttons.

### Finance
- **Finance** — log expenses and income, view spending by category. Parses bank SMS notifications (Indian banks supported). AI generates a personalised financial plan using the 50/30/20 framework.
- **SMS / Notification parsing** — automatically reads bank SMS and notification data to extract transactions locally.

### Mental Performance
- **Pomodoro** — timed focus sessions with rest periods. Daily focus minutes tracked.
- **Protected Habits** — accountability habits protected by a PIN/pattern. Tracks streaks and weekly completion.

### Entertainment
- **Movies & TV** — log films and shows you watch, with runtime and review.
- **Books** — track reading progress, log pages read per day, and maintain a reading list.

### Wellbeing
- **Digital Detox** — app usage monitoring and screen time goals.
- **Health Centre** — weekly workout sessions, body composition, sleep data from Health Connect, and AI-generated health insights.

### Home
- Two-column module grid for quick access to all features.
- Daily progress rings (calories, steps, habits, focus).
- Daily stats strip (gym sets, kcal in, kcal out, water, focus).
- Weekly progress card with 7-day view across habits, nutrition, gym, and focus.

---

## Activity Tab — Daily Progress Cards

The Activity tab shows a swipeable full-screen card for each tracked metric. Each card shows a large central metric, progress bar, two stat tiles, and a quick-action button.

| Card | Main Metric | Daily Goal |
|------|-------------|------------|
| Movement | Steps | 10,000 |
| Gym | Sets completed | — |
| Nutrition | Calories consumed | Your target |
| Hydration | Water intake (ml) | Your target |
| Focus | Pomodoro minutes | 90 min |
| Reading | Pages read | 30 pages |
| Entertainment | Watch time | 2 hour cap |
| Cardio | GPS distance (km) | 5 km |
| Gaming | Coming soon | — |
| This Week | 7-day summary | — |

Swipe left/right to navigate between cards. Use the date arrows at the top to view past days.

---

## Onboarding Flow

The onboarding wizard collects your profile and preferences across 12 steps:

| Step | Screen | What it collects |
|------|--------|------------------|
| 0 | Intro & Sign-In | Optional Google account (for cloud backup) |
| 1 | AI Setup | Your Gemini API key (stored on device only) |
| 2 | About You | Name, age, gender, height, weight |
| 3 | Goals | Health & life goals (multi-select) |
| 4 | Activity Level | Fitness level + preferred activity types |
| 5 | Schedule | Workout days + session duration per week |
| 6 | Workout Import | Upload workout images or paste text for AI analysis |
| 7 | Fitness Plan | AI generates a personalised workout programme |
| 8 | Calorie & Hydration | Daily calorie target + water goal (TDEE-calculated) |
| 9 | Finance | Monthly income, budget, currency, savings % |
| 10 | Modules | Enable/disable individual feature modules |
| 11 | Finance Plan | AI generates a personalised financial plan |

All collected data is saved locally to Hive. Only the data listed in the AI sections below is ever sent to Google's Gemini API.

---

## Data Collected

### Stored Locally (Hive — on device only)

| Data | Used For |
|------|----------|
| Profile (age, gender, height, weight) | TDEE calculations, AI prompts |
| Workout logs (exercises, sets, reps, weights) | Gym tracking, progression charts |
| GPS sessions (distance, duration, pace, HR) | Cardio Coach history |
| Health history (steps, calories, distance by day) | Trends, activity summary |
| Body weight log | Composition tracking |
| Food entries (meals, macros, calories per day) | Nutrition tracking |
| Water log | Hydration tracking |
| Pomodoro sessions | Focus tracking |
| Books (title, pages, reading logs) | Reading progress |
| Movies (title, runtime, watch date) | Entertainment log |
| Expenses & income | Finance dashboard |
| Habits (name, completions, streaks) | Habit tracking |
| Settings (goals, preferences, API key) | App configuration |

### Read from Health Connect
- Steps, active & total calories burned, distance
- Heart rate, resting HR, HRV
- Sleep sessions
- Exercise/workout sessions (from other apps)
- Weight, height, body fat %, lean body mass, bone mass
- Blood glucose, oxygen saturation, blood pressure, body temperature
- Hydration, respiratory rate, floors climbed

### SMS & Notifications (Finance module only)
- Bank SMS messages are read and parsed **locally** to extract transaction amount, merchant, and date
- Notifications from bank apps are parsed locally
- **No SMS or notification content is ever transmitted anywhere**

---

## AI Integration

Nudge uses **Google Gemini** via your personal API key from [Google AI Studio](https://aistudio.google.com/). The key is stored only on your device.

### What is sent to Gemini

| Feature | Data sent to Gemini |
|---------|-------------------|
| Fitness Plan | Age, gender, fitness level, goals, schedule, existing routine, workout images |
| Nutritional advice | Calorie & water goals, fitness plan text |
| Gym Chat Coach | Exercise name, last session sets/weights, gym profile |
| Finance Plan | Monthly income, budget, savings %, debt amount, investment goal, currency — **name is NOT sent** |
| Health Analysis | Sleep duration, HR trends, step trends, body composition values |
| Workout Image Import | Images you upload in onboarding Step 6 |

### What is never sent to AI
- Your name or any personally identifying information
- Raw SMS content or bank account numbers
- GPS coordinates or route data
- Individual food diary entries

---

## Architecture

| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter 3.29+ (stable) |
| State Management | `ChangeNotifier` with `ListenableBuilder` (no Provider package) |
| Local Storage | Hive |
| Health Data | `health` package → Health Connect (Android) |
| GPS Tracking | `geolocator` with foreground service + wake lock |
| Maps | `flutter_map` (OpenStreetMap tiles) |
| AI | `google_generative_ai` (Gemini 1.5 Flash) |
| Charts | `fl_chart` |
| Typography | Google Fonts — Outfit |
| Design System | `NudgeTokens` in `lib/app.dart` |

### Design System — NudgeTokens

All colours, gradients, and spacing constants live in `abstract class NudgeTokens` in [lib/app.dart](lib/app.dart). Import with:

```dart
import '../app.dart' show NudgeTokens;
```

Key colours:
- Background: `bg` #050A0D · `surface` #0C1317 · `card` #0F1A1F
- Accent: `purple` #7C4DFF · `green` #39D98A · `amber` #FFBF00 · `red` #FF4D6A · `blue` #5AC8FA
- Feature gradients: `gymA/gymB`, `moviesA/B`, `booksA/B`, `pomA/B`, `foodA/B`, `finA/B`

### Key Files

```
lib/
├── app.dart                    ← NudgeTokens + theme
├── main.dart
├── storage.dart                ← Hive box accessors
├── providers/app_state.dart    ← Root ChangeNotifier
├── screens/
│   ├── home_screen.dart        ← 2-column grid home
│   ├── activity/
│   │   ├── activity_summary_screen.dart  ← Full-screen swipeable daily cards
│   │   ├── activity_tracker_screen.dart  ← GPS Cardio Coach tracking UI
│   │   └── steps_detail_screen.dart
│   ├── gym/
│   │   ├── gym_screen.dart     ← Gym home
│   │   └── workout_editor.dart ← Exercise/sets logger with timer
│   ├── health/
│   │   ├── health_center_screen.dart
│   │   └── running_coach_list_screen.dart ← Cardio Coach history
│   ├── finance/
│   │   ├── finance_screen.dart
│   │   └── add_expense_sheet.dart
│   ├── onboarding/
│   │   └── onboarding_flow_screen.dart  ← 12-step wizard
│   └── food/, books/, movies/, pomodoro/, protected/, settings/
├── services/
│   ├── gps_tracking_service.dart   ← GPS singleton + foreground service
│   └── health_center_service.dart
├── utils/
│   ├── health_service.dart     ← Health Connect bridge
│   ├── gemini_service.dart     ← Gemini API wrapper
│   └── finance_service.dart
└── widgets/
    ├── weekly_progress_card.dart   ← 7-day summary (fullScreen mode supported)
    └── daily_progress_rings.dart   ← Circular progress rings
```

---

## Setup & Running

### Requirements
- Flutter 3.29+ (stable channel)
- Android device running Android 9+ (API 28+)
- Health Connect installed on device
- (Optional) Gemini API key from [Google AI Studio](https://aistudio.google.com/)

### Run

```bash
flutter pub get
flutter run --debug
```

#### Windows (if flutter not on PATH)
```
"F:\Development\Flutter\flutter_windows_3.29.3-stable\flutter\bin\flutter.bat" run --debug
```

### First Launch
The 12-step onboarding wizard runs. Every step can be skipped. Most features work without a Gemini API key.

### Health Connect Permissions
Grant permissions when prompted. If denied, re-grant from: **Settings → Health Centre → Manage Permissions**.

---

## Privacy

- **All data is local** — stored in Hive on your device
- **No analytics, no ads, no telemetry**
- **No Nudge servers** — the app does not connect to any Nudge-owned backend
- **AI is opt-in** — Gemini features only activate when you provide your own API key
- **SMS parsing is local** — no SMS content is ever transmitted

---

## Modules

Enable or disable modules in onboarding Step 10 or **Settings → Modules**:

| Module | Default | Description |
|--------|---------|-------------|
| Gym & Fitness | On | Workout logging + AI coach |
| Food & Nutrition | On | Meal logging + macros |
| Finance | On | Expense tracking + AI plan |
| Movies | On | Watch log |
| Books | On | Reading tracker |
| Pomodoro | On | Focus timer |
| Protected Habits | On | PIN-protected accountability habits |
| Digital Detox | On | App usage monitoring |
