# Nudge — Screens, Widgets & Architecture Reference

> Auto-generated 2026-03-24. Single source of truth for UI structure.

---

## Table of Contents

1. [Colour Palette — NudgeTokens](#colour-palette--nudgetokens)
2. [Navigation Overview](#navigation-overview)
3. [Root / Shell](#root--shell)
4. [Authentication & Onboarding](#authentication--onboarding)
5. [Home](#home)
6. [Activity & Health](#activity--health)
7. [Gym & Fitness](#gym--fitness)
8. [Pomodoro / Focus](#pomodoro--focus)
9. [Books](#books)
10. [Movies](#movies)
11. [Food & Nutrition](#food--nutrition)
12. [Finance](#finance)
13. [Protected Habits](#protected-habits)
14. [Public Habits & Day Trackers](#public-habits--day-trackers)
15. [Digital Wellbeing](#digital-wellbeing)
16. [Settings](#settings)
17. [Export](#export)
18. [Shared Widgets](#shared-widgets)
19. [UI Framework Widgets](#ui-framework-widgets)
20. [Dead Code](#dead-code)
21. [Services & Utilities](#services--utilities)
22. [Full File Tree](#full-file-tree)

---

## Colour Palette — NudgeTokens

Defined in `lib/app.dart` → `abstract class NudgeTokens`.
Import anywhere with `import '../app.dart' show NudgeTokens;`

### Background layers (darkest → lightest)

| Token | Hex | Usage |
|---|---|---|
| `bg` | `#050A0D` | Page/scaffold background |
| `surface` | `#0C1317` | Cards sitting on bg, tab bars |
| `card` | `#0F1A1F` | Content cards (slight warm blue) |
| `elevated` | `#111B20` | Input fields, chips, popovers |

### Accent colours

| Token | Hex | Usage |
|---|---|---|
| `purple` | `#7C4DFF` | Primary CTA, Pomodoro, Detox, protected |
| `purpleDim` | `#4A2DCC` | Pressed state, secondary purple |
| `blue` | `#5AC8FA` | Screen Time, Health, info |
| `green` | `#39D98A` | Success, On-track, active |
| `amber` | `#FFBF00` | Warnings, peak values |
| `red` | `#FF4D6A` | Over-limit, delete, errors |

### Text colours

| Token | Hex | Usage |
|---|---|---|
| `textHigh` | `#FFFFFF` | Primary headings, values |
| `textMid` | `#B0C4CF` | Sub-labels, descriptions |
| `textLow` | `#5A7582` | Placeholders, disabled, captions |

### Borders

| Token | Value | Usage |
|---|---|---|
| `border` | `white @ 8%` | Default card/container border |
| `borderHi` | `white @ 13%` | Focused/highlighted border |

### Feature gradients (used on ShortcutCard / home grid)

| Token pair | From | To | Feature |
|---|---|---|---|
| `gymA` / `gymB` | `#1C2A17` | `#B7FF5A` | Gym / fitness |
| `moviesA` / `moviesB` | `#2D1938` | `#FF2D95` | Movies / entertainment |
| `booksA` / `booksB` | `#0E2A1C` | `#39D98A` | Books / reading |
| `pomA` / `pomB` | `#1B1B2F` | `#7C4DFF` | Pomodoro / focus |
| `protA` / `protB` | `#0B1D2A` | `#5AC8FA` | Protected habits |
| `exportA` / `exportB` | `#0E1F15` | `#4CD964` | Export |
| `finA` / `finB` | `#0D141C` | `#2990FF` | Finance |
| `foodA` / `foodB` | `#2A1B0D` | `#FF9500` | Food / nutrition |
| `healthA` / `healthB` | `#0A1924` | `#5AC8FA` | Health Center |

---

## Navigation Overview

```
main.dart
└── NudgeApp (app.dart)
    ├── [first launch] SignInScreen
    │   └── onDone ──────────────────────────────┐
    ├── [onboarding] OnboardingScreen             │
    │   └── _finish() ───────────────────────────┤
    └── HomeScreen  ◄────────────────────────────┘
        ├── Tab 0 · _HomeTab  (2-col shortcut grid)
        │   ├── → GymScreen
        │   ├── → PomodoroScreen
        │   ├── → FoodScreen
        │   ├── → FinanceScreen
        │   ├── → BooksScreen
        │   ├── → MoviesScreen
        │   ├── → HealthCenterScreen
        │   ├── → ProtectedGateScreen → ProtectedHabitsScreen
        │   ├── → MyHabitsScreen
        │   ├── → DayTrackerScreen
        │   └── → DigitalWellbeingScreen
        │
        ├── Tab 1 · ActivitySummaryScreen
        │   ├── → ActivityTrackerScreen (GPS live)
        │   ├── → StepsDetailScreen
        │   ├── → GymScreen
        │   └── → HealthCenterScreen
        │
        ├── Tab 2 · _ProgressTab (charts/stats)
        │
        └── Tab 3 · SettingsScreen
            ├── → ThemeSettingsScreen
            ├── → AiErrorLogScreen
            ├── → DeveloperOptionsScreen
            ├── → NutritionSettingsScreen
            ├── → DigitalWellbeingScreen (initialTab: 1)
            ├── → ExportScreen
            └── → RawNotificationScreen
```

---

## Root / Shell

### `lib/main.dart`
Entry point. Runs `async` init sequence:
1. `NotificationService().init()`
2. `Hive.initFlutter()` + `AppStorage.init()`
3. `DetoxService.instance.init()`
4. `Firebase.initializeApp()`
5. `Workmanager().initialize(callbackDispatcher)` (background backup)
6. `await AutoBackupService.rescheduleIfEnabled()`
7. `runApp(NudgeApp())` → `WidgetService.updateAll()`

---

### `lib/app.dart`
**`NudgeTokens`** — abstract class, all design tokens (see colour table above).
**`NudgeApp`** — `StatefulWidget`, root widget.
Listens to `ThemeService` via `ListenableBuilder`, switches between 5 themes (default, brutal, terminal, cute, neumorphic).
Auth flow: `StreamBuilder` on `AuthService.authStateChanges` → shows `SignInScreen` → `OnboardingScreen` → `HomeScreen`.

---

## Authentication & Onboarding

### `lib/screens/auth/sign_in_screen.dart`
| | |
|---|---|
| Class | `SignInScreen` (StatefulWidget) |
| Opens from | `NudgeApp` (first launch) |
| Opens | Nothing (calls `onDone` callback) |
| Props | `onDone: VoidCallback` |

One-page optional Google Sign-In. "Skip" available for offline use. Signs in via `AuthService.signInWithGoogle()`.

---

### `lib/screens/onboarding_screen.dart`
| | |
|---|---|
| Class | `OnboardingScreen` (StatefulWidget) |
| Opens from | `NudgeApp` (after sign-in, first launch) |
| Opens | `HomeScreen` via `_finish()` |

11-step onboarding wizard (PageView):
- Step 0: Welcome / name entry
- Step 1: Module selection (gym, food, finance, movies, books, detox)
- Steps 2–5: Fitness profile (level, goal, gym commitment, cardio days)
- Step 6: Water goal
- Step 7: Budget setup
- Step 8: AI/Gemini API key entry
- Step 9: AI life plan generation (calls Gemini)
- Step 10: Summary & launch

---

### `lib/screens/onboarding/privacy_intro_screen.dart`
| | |
|---|---|
| Class | `PrivacyIntroScreen` (StatelessWidget) |
| Sub-widgets | `_FeatureRow`, `_OrbitIconSystem` (orbit animation) |

Static privacy/security explainer shown early in onboarding.

---

### `lib/screens/onboarding/orbit_demo_screen.dart`
| | |
|---|---|
| Class | `OrbitDemoScreen` (StatelessWidget) |

"Establishing Orbit" splash/loading screen with animations. Shown during AI plan generation in onboarding.

---

### `lib/screens/onboarding/restore_from_cloud_screen.dart`
| | |
|---|---|
| Class | `RestoreFromCloudScreen` (StatefulWidget) |
| Opens from | Onboarding (optional step) |

Passphrase prompt + `FirebaseBackupService.restore()` call. Re-runs `AppStorage.init()` to restore all Hive boxes from Firebase.

---

## Home

### `lib/screens/home_screen.dart`
| | |
|---|---|
| Class | `HomeScreen` (StatefulWidget) |
| State mixin | `TickerProviderStateMixin` |
| Tab count | 4 (IndexedStack) |

The top-level navigation shell. Manages a `_NudgeNavBar` (custom bottom nav).

**Private sub-widgets defined in the same file:**

| Widget | Description |
|---|---|
| `_HomeTab` | 2-column shortcut grid. Each cell is a `ShortcutCard` leading to a module. Also shows inline daily stats (water, steps, active calories, focus mins, streaks). |
| `_ProgressTab` | Progress view with charts and summaries across all modules. |
| `_NudgeNavBar` | Custom bottom navigation bar with 4 animated icons. |

**Data loaded at init:**
- Today's health summary (HC + local) via `HealthCenterService`
- Water intake via `HealthService`
- Step count via `HealthService`
- Finance balance via `FinanceService`
- Pomodoro minutes via box
- App usage via `UsageService` (for Digital Wellbeing card badge)

---

## Activity & Health

### `lib/screens/activity/activity_summary_screen.dart`
| | |
|---|---|
| Class | `ActivitySummaryScreen` (StatefulWidget) |
| Opens from | `HomeScreen` Tab 1 |
| Opens | `ActivityTrackerScreen`, `StepsDetailScreen`, `GymScreen`, `HealthCenterScreen` |

Unified dashboard. Aggregates gym sessions, cardio, steps, water, focus time, nutrition for the day. Each metric is a tappable card that deep-links to the relevant detail screen.

---

### `lib/screens/activity/activity_tracker_screen.dart`
| | |
|---|---|
| Class | `ActivityTrackerScreen` (StatefulWidget) |
| Opens from | `ActivitySummaryScreen`, `GymScreen` |
| Package deps | `flutter_map`, `latlong2`, `geolocator` |

Real-time GPS workout tracking:
- Live map with route polyline
- Distance, duration, current pace, average pace
- Heart rate integration (Health Connect)
- Activity type selector (run / walk / hike / cycle / trail)
- Session summary + auto-log on finish via `GpsTrackingService`

---

### `lib/screens/activity/steps_detail_screen.dart`
| | |
|---|---|
| Class | `StepsDetailScreen` (StatefulWidget) |
| Opens from | `ActivitySummaryScreen`, `HealthCenterScreen` |

7-day step chart + daily breakdown. Sourced from Health Connect.

---

### `lib/screens/health/health_center_screen.dart`
| | |
|---|---|
| Class | `HealthCenterScreen` (StatefulWidget) |
| Opens from | `HomeScreen`, `ActivitySummaryScreen` |
| Opens | `SleepScreen`, `WaterHistoryScreen`, `GoalsScreen`, `BodyCompositionScreen`, `StepsDetailScreen`, `RunningCoachListScreen`, `GymScreen`, `AnalysisReportScreen` |

Main health hub. Date-navigable daily summary. Metric cards:
- Active calories / BMR
- Steps & distance
- Water intake (with `WaterTrackerCard`)
- Heart rate / HRV
- Sleep duration
- Body composition snapshot

Day Boundary setting greyed out (Coming Soon badge, `opacity: 0.45`).

---

### `lib/screens/health/sleep_screen.dart`
| | |
|---|---|
| Class | `SleepScreen` (StatefulWidget) |
| Opens from | `HealthCenterScreen` |

Sleep log viewer and editor. Auto-syncs from Health Connect. Manual edit workflow with validation. Sleep quality score and trend chart.

---

### `lib/screens/health/water_history_screen.dart`
| | |
|---|---|
| Class | `WaterHistoryScreen` (StatefulWidget) |
| Opens from | `HealthCenterScreen` |

30-day water intake chart + per-day log list. Goal adjustment dialog. Data via `HealthService`.

---

### `lib/screens/health/goals_screen.dart`
| | |
|---|---|
| Class | `GoalsScreen` (StatefulWidget) |
| Opens from | `HealthCenterScreen` |
| Opens | `AnalysisReportScreen` |

Health goal CRUD (create, read, update, delete). Each goal has a name, target value, unit, and deadline. AI coaching generates insights via `AiAnalysisService`.

---

### `lib/screens/health/body_composition_screen.dart`
| | |
|---|---|
| Class | `BodyCompositionScreen` (StatefulWidget) |
| Opens from | `HealthCenterScreen` |

Tabbed body metrics tracker. 12 tracked metrics:
body fat %, skeletal muscle %, visceral fat, body water %, bone mass, BMI, BMR, metabolic age, protein %, subcutaneous fat %, trunk fat %, right/left limb fat %.

Sources: OCR from scale photos (AI-parsed), Health Connect sync.

---

### `lib/screens/health/analysis_report_screen.dart`
| | |
|---|---|
| Class | `AnalysisReportScreen` (StatelessWidget) |
| Opens from | `GoalsScreen`, `GymScreen` |
| Props | `content: String` (markdown), `timestamp: DateTime` |

Read-only AI insights report rendered as markdown.

---

### `lib/screens/health/running_coach_list_screen.dart`
| | |
|---|---|
| Class | `RunningCoachListScreen` (StatefulWidget) |
| Opens from | `HealthCenterScreen` |
| Opens | `RunningCoachScreen` (individual run) |

Cardio/run session list with AI coaching. Merges Health Connect sessions + GPS-tracked sessions. Shows personal records, race time predictions, training load, run streak.

---

### `lib/screens/health/running_coach_screen.dart`
| | |
|---|---|
| Opens from | `RunningCoachListScreen` |

Individual run deep-dive: split paces, heart rate zones, map replay, AI coaching notes.

---

## Gym & Fitness

### `lib/screens/gym/gym_screen.dart`
| | |
|---|---|
| Class | `GymScreen` (StatefulWidget, ~800 lines) |
| Opens from | `HomeScreen`, `ActivitySummaryScreen`, `HealthCenterScreen` |
| Opens | `GymSettingsSheet`, `GymProgressCharts`, `GymRoutinesScreen`, `ProfileSheet`, `AnalysisReportScreen`, `MuscleMannequin`, `ExerciseDetailSheet`, `ActivityTrackerScreen` |

Main fitness tracking screen. Three data sources: manual gym entries, Health Connect workouts, GPS sessions.

Key features:
- Log exercises with sets, reps, weight
- Log cardio sessions (distance, duration, calories)
- HC session sync + validation
- AI routine generation (`AiRoutineGenerator`)
- Weekly stats (volume, session count, streak)
- PDF export (`PdfExportService`)
- GymChat (AI coach)

---

### `lib/screens/gym/gym_settings_screen.dart`
| | |
|---|---|
| Class | `GymSettingsSheet` (StatefulWidget) |
| Type | Bottom sheet (modal) |
| Opens from | `GymScreen` |
| Props | `targetDaysPerWeek: int` |

Settings for target workout days/week and Health Connect toggle.

---

### `lib/screens/gym/gym_progress_charts.dart`
| | |
|---|---|
| Class | (StatefulWidget) |
| Opens from | `GymScreen` |
| Deps | `fl_chart` |

Visual progress charts: volume over time, PR history per exercise, body weight trend.

---

### `lib/screens/gym/gym_routines_screen.dart`
| | |
|---|---|
| Class | `GymRoutinesScreen` (StatefulWidget) |
| Opens from | `GymScreen` |

Saved workout routine manager. View, activate, or delete routines generated by AI or user-created.

---

### `lib/screens/gym/profile_sheet.dart`
| | |
|---|---|
| Type | Bottom sheet (modal) |
| Opens from | `GymScreen` |

User profile editor: name, height, weight, age, fitness level. Used for AI context.

---

### `lib/screens/gym/muscle_mannequin.dart`
| | |
|---|---|
| Class | `MuscleMannequin` (StatefulWidget) |
| Opens from | `GymScreen` |

Interactive body map. Colours muscle groups based on workout data. Front/back toggle.

---

### `lib/screens/gym/exercise_detail_sheet.dart`
| Type | Bottom sheet (modal) |
|---|---|
| Opens from | `GymScreen` |

Per-exercise breakdown: PR, average weight, volume history, last performed.

---

### `lib/screens/gym/exercise_picker_sheet.dart`
| Type | Bottom sheet (modal) |
|---|---|
| Opens from | `GymScreen` (when adding exercise to workout) |

Searchable exercise list grouped by muscle group. Returns selected exercise.

---

### `lib/screens/gym/workout_editor.dart`
| Opens from | `GymScreen` |
|---|---|

Workout session form. Add/remove exercises, edit sets/reps/weight inline.

---

### Other gym files

| File | Role |
|---|---|
| `exercise_thumbnail.dart` | Small `[icon + name]` widget used in workout lists |
| `exercise_info.dart` | Exercise description + instructions panel |
| `exercise_illustration.dart` | SVG/image visual for exercise form |
| `exercise_db.dart` | Static exercise database (name, muscle groups, type) |
| `calories.dart` | Calorie burn calculation helpers |
| `stickman_engine.dart` | Stick-figure pose renderer used by MuscleMannequin |
| `gym_screen_imports.dart` | Barrel import file (reduces gym_screen.dart header) |

---

## Pomodoro / Focus

### `lib/screens/pomodoro/pomodoro_screen.dart`
| | |
|---|---|
| Class | `PomodoroScreen` (StatefulWidget) |
| Opens from | `HomeScreen` |
| Opens | `PomodoroStatsScreen`, `ProjectEditorSheet`, `ManualLogSheet` |

Main focus timer. Features:
- Work / break mode toggle
- Visual `TimerRing` progress
- Project selector (focus time logged per project)
- Pomodoro blocking integration via `PomodoroService` (native MethodChannel)
- Preset time buttons (15 / 25 / 45 / 60 min)

Private sub-widgets:

| Widget | Description |
|---|---|
| `_Stepper` | +/− control with long-press acceleration for time adjustment |
| `_StepBtn` | Small icon button used inside `_Stepper` |

---

### `lib/screens/pomodoro/pomodoro_stats_screen.dart`
| | |
|---|---|
| Class | `PomodoroStatsScreen` (StatefulWidget) |
| Opens from | `PomodoroScreen` |

Historical stats: daily/weekly focus minutes, per-project breakdown, streaks, log list.

---

### `lib/screens/pomodoro/timer_ring.dart`
| | |
|---|---|
| Class | `TimerRing` (StatelessWidget) |
| Sub-widget | `_RingPainter` (CustomPainter) |
| Used by | `PomodoroScreen` |

Circular arc progress ring with inner glow. Props: `progress` (0.0–1.0), `color`, `label`, `size`.

---

### `lib/screens/pomodoro/pomodoro_engine.dart`
Singleton service (not a widget). Manages timer state (countdown, mode, ticking). Sends notifications via `NotificationService`. Used by `PomodoroScreen`.

---

### `lib/screens/pomodoro/project_editor_sheet.dart`
| Type | Bottom sheet (modal) |
|---|---|
| Opens from | `PomodoroScreen` |

Create / edit project form: name, color, icon. Returns project map.

---

### `lib/screens/pomodoro/manual_log_sheet.dart`
| Type | Bottom sheet (modal) |
|---|---|
| Opens from | `PomodoroScreen` |

Manually log a past focus session: project, duration, date.

---

## Books

### `lib/screens/books/books_screen.dart`
| | |
|---|---|
| Class | `BooksScreen` (StatefulWidget) |
| Opens from | `HomeScreen` |
| Opens | `BookEditorSheet` |

Reading tracker. Books stored in `booksBox['books']`. Features:
- Filter by status (reading / finished / dropped / want to read)
- Stats strip: total books, total pages, active streaks
- `BooksStatsHeader` + list of `BookCard` widgets

---

### `lib/screens/books/book_card.dart`
| | |
|---|---|
| Class | `BookCard` (StatelessWidget) |
| Used by | `BooksScreen` |
| Props | `book: Map`, `onTap`, `onEdit` |

Shows title, author, genre (`Pill`), pages read / total, linear progress bar, start/end dates.

---

### `lib/screens/books/book_editor_sheet.dart`
| | |
|---|---|
| Class | `BookEditorSheet` (StatefulWidget) |
| Type | Bottom sheet (modal) |
| Opens from | `BooksScreen` |
| Returns | `Map` with `__action: 'save' | 'delete'` |

Fields: title, author, genre, total pages, pages read, status, start date, end date.

---

### `lib/screens/books/books_stats_header.dart`
| | |
|---|---|
| Class | `BooksStatsHeader` (StatelessWidget) |
| Used by | `BooksScreen` |

Summary bar: books finished, pages read, current streak, average pace.

---

## Movies

### `lib/screens/movies/movies_screen.dart`
| | |
|---|---|
| Class | `MoviesScreen` (StatefulWidget) |
| Opens from | `HomeScreen` |
| Opens | `MovieEditorSheet`, `WatchEditorSheet` |

Movie / series / anime tracker. Stored in `moviesBox['movies']`. Features:
- Filter by type (movie, series, anime, documentary)
- Stats: total runtime minutes, language breakdown
- `MoviesStatsHeader` + list of `MovieCard`

---

### `lib/screens/movies/movie_card.dart`
| | |
|---|---|
| Class | `MovieCard` (StatelessWidget) |
| Used by | `MoviesScreen` |

Shows title, type badge (`Pill`), language, runtime, year, season/episode count, rewatch count, watch date.

---

### `lib/screens/movies/movie_editor_sheet.dart`
| | |
|---|---|
| Class | `MovieEditorSheet` (StatefulWidget) |
| Type | Bottom sheet (modal) |
| Opens from | `MoviesScreen` |
| Returns | `Map` with `__action: 'save' | 'delete'` |

AI auto-fill (Gemini lookups title → runtime, year, type). Fields: title, type, language, runtime, year, season, episodes watched, rewatch, watch date.

---

### `lib/screens/movies/watch_editor_sheet.dart`
| Type | Bottom sheet (modal) |
|---|---|
| Opens from | `MoviesScreen` (log a new watch session for an existing entry) |

---

### `lib/screens/movies/watch_item_card.dart`
| | |
|---|---|
| Class | `WatchItemCard` (StatelessWidget) |
| Used by | `MoviesScreen` (watch history list) |

Compact card showing date, episode range, notes for a single watch session.

---

### `lib/screens/movies/movies_stats_header.dart`
| | |
|---|---|
| Class | `MoviesStatsHeader` (StatelessWidget) |
| Used by | `MoviesScreen` |

Summary strip: total runtime (hrs), total titles, language count, top genre.

---

## Food & Nutrition

### `lib/screens/food/food_screen.dart`
| | |
|---|---|
| Class | `FoodScreen` (StatefulWidget) |
| Opens from | `HomeScreen` |
| Opens | `AddFoodSheet`, `EditFoodSheet`, `NutritionSettingsScreen` |

Daily macro tracker. Date-navigable (past / future days supported). Features:
- Calorie goal ring
- Macro bars (protein, carbs, fat, fibre)
- Meal-grouped entry list (Breakfast / Lunch / Dinner / Snack)
- AI-powered reanalysis of entire meal

---

### `lib/screens/food/add_food_sheet.dart`
| | |
|---|---|
| Class | `AddFoodSheet` (StatefulWidget) |
| Type | Bottom sheet (modal) |
| Opens from | `FoodScreen` (_addFood, _addFoodToMeal, _reanalyzeMeal) |
| Props | `initialMeal`, `initialDescription`, `date` (for correct-day saving) |

AI-powered food entry. Input modes:
1. Free-text description → Gemini parses to structured nutrition
2. Barcode scan (`mobile_scanner`)
3. Photo/image recognition
4. Food library search (history-based)

Uses `MealSelector` to pick meal type. Saves via `FoodService.saveEntry`.

---

### `lib/screens/food/edit_food_sheet.dart`
| | |
|---|---|
| Class | `EditFoodSheet` (StatefulWidget) |
| Type | Bottom sheet (modal) |
| Opens from | `FoodScreen` (tap entry) |

Edit name, calories, macros, servings, meal type of an existing entry.

---

### `lib/screens/food/nutrition_settings_screen.dart`
| | |
|---|---|
| Class | `NutritionSettingsScreen` (StatefulWidget) |
| Opens from | `FoodScreen`, `SettingsScreen` |

Body profile (height, weight, age, sex, activity level, goal) → auto-calculates TDEE and macro targets. Saves to `settingsBox`.

---

### `lib/screens/food/meal_selector.dart`
| | |
|---|---|
| Class | `MealSelector` (StatelessWidget) |
| Used by | `AddFoodSheet` |
| Props | `value: String`, `onChanged: ValueChanged<String>` |

Horizontal pill row: Breakfast / Lunch / Dinner / Snack.

---

## Finance

### `lib/screens/finance/finance_screen.dart`
| | |
|---|---|
| Class | `FinanceScreen` (StatefulWidget) |
| Opens from | `HomeScreen` |
| Opens | `AddExpenseSheet`, `BudgetEditorSheet`, `RawNotificationScreen` |

Monthly budget tracker. Features:
- Month navigation
- Income vs expenses summary bar
- Category-wise breakdown with progress bars
- SMS-parsed bank transactions (Indian banks, `IndianBankSmsParser`)
- Budget target per month (`BudgetEditorSheet`)

---

### `lib/screens/finance/add_expense_sheet.dart`
| | |
|---|---|
| Class | `AddExpenseSheet` (StatefulWidget) |
| Type | Bottom sheet (modal) |
| Opens from | `FinanceScreen` |

Fields: amount, merchant/description, category, note, date, type (expense / income). Category auto-suggested from merchant history.

---

### `lib/screens/finance/budget_editor_sheet.dart`
| Type | Bottom sheet (modal) |
|---|---|
| Opens from | `FinanceScreen` |

Set monthly budget target. Single number field with quick-select presets.

---

### `lib/screens/finance/raw_notification_screen.dart`
| | |
|---|---|
| Class | `RawNotificationScreen` (StatefulWidget) |
| Opens from | `FinanceScreen`, `SettingsScreen` |

Raw SMS / notification log viewer for debugging bank SMS parsing. Read-only list.

---

## Protected Habits

### `lib/screens/protected/protected_gate.dart`
| | |
|---|---|
| Class | `ProtectedGateScreen` (StatefulWidget) |
| Opens from | `HomeScreen` |
| Opens | `ProtectedHabitsScreen` on biometric success |
| Deps | `local_auth` |

Biometric (fingerprint / face) authentication gate. Falls back to device PIN.

---

### `lib/screens/protected/protected_habits_screen.dart`
| | |
|---|---|
| Class | `ProtectedHabitsScreen` (StatefulWidget) |
| Opens from | `ProtectedGateScreen` |
| Opens | `HabitDetailScreen`, `HabitEditorSheet` |

PIN-locked personal habit tracker. Date-navigable. Data in `protectedBox['habits']` and `protectedBox['habit_logs']`.

Features:
- Build habits (increment count toward target)
- Quit habits (track relapses, zero = success)
- 7-day mini bar graph per habit
- Color-coded status (green = complete, red = over/relapse)
- Daily reminders via `NotificationService`

---

### `lib/screens/protected/habit_card.dart` *(the real one)*
| | |
|---|---|
| Class | `HabitCard` (StatelessWidget) |
| Used by | `ProtectedHabitsScreen`, `MyHabitsScreen` |
| Props | `title`, `iconCode`, `count`, `last7`, `type`, `target`, callbacks |

Compact card with icon, name, today's count, +/− buttons, mini bar graph, colour-coded progress.

---

### `lib/screens/protected/habit_detail_screen.dart`
| | |
|---|---|
| Class | `HabitDetailScreen` (StatelessWidget) |
| Opens from | `ProtectedHabitsScreen`, `MyHabitsScreen` |
| Props | `habit: Map`, `logs: List` |

30-day calendar heatmap + streak statistics (current streak, longest streak, success rate). Read-only.

---

### `lib/screens/protected/habit_editor_sheet.dart`
| | |
|---|---|
| Class | `HabitEditorSheet` (StatefulWidget) |
| Type | Bottom sheet (modal) |
| Opens from | `ProtectedHabitsScreen`, `MyHabitsScreen` |
| Returns | `Map` with `__action: 'save' | 'delete'` |

Fields: name, icon (opens `IconPickerSheet`), type (build / quit), daily target, reminder time.

---

### `lib/screens/protected/icon_picker_sheet.dart`
| Type | Bottom sheet (modal) |
|---|---|
| Opens from | `HabitEditorSheet` |

Scrollable emoji/icon grid. Returns selected icon codepoint.

---

### `lib/screens/protected/mini_bar_graph.dart`
| | |
|---|---|
| Class | `MiniBarGraph` (StatelessWidget) |
| Used by | `HabitCard` |

7-bar micro chart. Each bar is proportional to the day's count vs target.

---

### `lib/screens/protected/habit_routine_card.dart`
| | |
|---|---|
| Class | `HabitRoutineCard` (StatelessWidget) |
| Used by | `ProtectedHabitsScreen` |

Compact card showing a day's routine summary (completed count / total habits).

---

### `lib/screens/protected/protected_counters_gate.dart`
Referenced internally. Uses `AppScaffold`. Navigates to `ProtectedCountersScreen`.

---

### `lib/screens/protected/protected_counters_screen.dart`
Placeholder screen. Not yet implemented.

---

## Public Habits & Day Trackers

### `lib/screens/habits/my_habits_screen.dart`
| | |
|---|---|
| Class | `MyHabitsScreen` (StatefulWidget) |
| Opens from | `HomeScreen` |
| Opens | `HabitDetailScreen`, `HabitEditorSheet`, `ProtectedGateScreen` (link) |

Same mechanics as `ProtectedHabitsScreen` but publicly accessible (no biometric gate). Data in `protectedBox['pub_habits']`. Habits organised into 7 categories: morning, evening, fitness, mindfulness, finance, learning, anytime.

---

### `lib/screens/trackers/day_tracker_screen.dart`
| | |
|---|---|
| Class | `DayTrackerScreen` (StatefulWidget) |
| Opens from | `HomeScreen` |

Multi-tracker for long-form challenges (e.g. "Day 14 of 100 no-sugar"). Each tracker has:
- Name, colour, optional target count
- Mode: date-range (auto increments) or manual (tap to advance)
- Visual progress bar with "Day X of Y" label
- Add / edit / delete via bottom sheet

---

## Digital Wellbeing

### `lib/screens/digital_wellbeing/digital_wellbeing_screen.dart`
| | |
|---|---|
| Class | `DigitalWellbeingScreen` (StatefulWidget) |
| Opens from | `HomeScreen` (Screen Time card & Detox card), `SettingsScreen` |
| Props | `initialTab: int` (0=Screen Time, 1=Detox) |
| Opens | `AppDetailScreen` |

Two-tab screen:

**Tab 0 — Screen Time**
- Daily / Weekly toggle chips + `tune_rounded` filter icon (opens `_AppTrackerSheet`)
- **Daily view**: date nav bar, `_DayHeroCard` (total + tracked stats), two sections: *Tracked Apps* (blue label) and *Other Apps* — each section uses `_AppCalorieCard` tiles
- **Weekly view**: `_WeeklyBarsCard` (tap bar → shows inline day apps in `_APPS ON {date}` section without leaving weekly view), `_WeeklyStatsStrip`, `_WeeklyAppRow` top-apps list
- Each app tile taps → `AppDetailScreen`

**Tab 1 — Detox**
- Empty state: `_DetoxEmptyState` (🌿 motivational, tip cards)
- Active state: `_ActiveBlockingBanner` (🛡️ shield) + schedule list (`_buildScheduleTile`)
- FAB → `_EditScheduleSheet` to create schedule
- Each schedule tile → `_EditScheduleSheet` to edit
- Active schedules show green border + "Active Now" badge

**Private widgets in file:**

| Widget | Description |
|---|---|
| `_ViewChip` | Daily / Weekly toggle pill |
| `_DayHeroCard` | Hero stats card with big total time, progress bar, TRACKED/TOTAL or STATUS/GOAL stats |
| `_AppCalorieCard` | Per-app card (calorie-card template): icon, name, %, big time, progress bar, THIS WEEK / AVG DAY cells |
| `_WeeklyBarsCard` | 7-day bar chart; tap highlights bar + shows inline day section |
| `_WeeklyStatsStrip` | 3-cell strip: WEEK TOTAL / AVG PER DAY / PEAK DAY |
| `_WeeklyAppRow` | Compact app row with mini 7-day bars + week total |
| `_AppTrackerSheet` | Searchable checkbox list of installed apps for tracking selection |
| `_DetoxEmptyState` | 🌿 motivational empty state with `_TipCard` list |
| `_TipCard` | Single tip card (emoji + title + body) |
| `_ActiveBlockingBanner` | 🛡️ green banner shown when any schedule is currently active |
| `_EditScheduleSheet` | Full detox schedule form (name, times, days, app picker with doom-app detection) |
| `_DateNavBar` | Date navigation row (← date label TODAY →) |
| `_PermissionView` | Usage-access permission request page |
| `AppDetailScreen` | **Separate screen**: per-app detail with 7-day chart, 3-stat header, daily breakdown list |

---

## Settings

### `lib/screens/settings_screen.dart`
| | |
|---|---|
| Class | `SettingsScreen` (StatefulWidget) |
| Opens from | `HomeScreen` Tab 3 |
| Opens | `ThemeSettingsScreen`, `AiErrorLogScreen`, `DeveloperOptionsScreen`, `NutritionSettingsScreen`, `DigitalWellbeingScreen`, `ExportScreen`, `RawNotificationScreen`, `SignInScreen` |

Sections:
1. **Profile / Account** — Google Sign-In status, sign-out, delete account
2. **AI Settings** — Gemini API key pair (key A/B, active index), model selector (25+ Gemini variants), test prompt
3. **Permissions** — Health Connect, usage access, notification listener, overlay
4. **App Settings** — Reminder time picker, theme → `ThemeSettingsScreen`
5. **Nutrition** → `NutritionSettingsScreen`
6. **Data & Export**
   - Manual backup → passphrase dialog → `FirebaseBackupService.backup()`
   - Restore → passphrase dialog → `FirebaseBackupService.restore()`
   - Nightly Auto-Backup toggle → `AutoBackupService.enable()` + battery optimisation prompt
   - Export → `ExportScreen`
7. **Digital Wellbeing** → `DigitalWellbeingScreen(initialTab: 1)`
8. **Debug** → `AiErrorLogScreen`, `DeveloperOptionsScreen`
9. **Onboarding** reset button
10. **App update** check via `UpdateService`

---

### `lib/screens/settings/theme_settings_screen.dart`
| | |
|---|---|
| Class | `ThemeSettingsScreen` (StatefulWidget) |
| Opens from | `SettingsScreen` |

Select from 5 themes: default, brutal, terminal, cute, neumorphic. Saves via `ThemeService`.

---

### `lib/screens/settings/ai_error_log_screen.dart`
| | |
|---|---|
| Class | `AiErrorLogScreen` (StatefulWidget) |
| Opens from | `SettingsScreen` |

Scrollable list of AI / background errors logged to `settingsBox['ai_errors']`. Clear all button.

---

### `lib/screens/settings/developer_options_screen.dart`
| | |
|---|---|
| Opens from | `SettingsScreen` |

Developer-only options: data seeding, mock data injection, cache clearing.

---

## Export

### `lib/screens/export/export_screen.dart`
| | |
|---|---|
| Class | `ExportScreen` (StatefulWidget) |
| Opens from | `SettingsScreen` |

Dropdown selector for 10 export types → CSV text rendered in selectable `Text`. Copy-to-clipboard button.

Export types via `CsvExport`:
1. Pomodoro Logs
2. Pomodoro Projects
3. Gym Workouts
4. Gym Cardio
5. Protected Habits
6. Protected Habit Logs
7. Movies
8. Books
9. Health History (totals)
10. Health Logs (manual)

---

## Shared Widgets

### `lib/widgets/empty_card.dart`
| | |
|---|---|
| Class | `EmptyCard` (StatelessWidget) |
| Props | `title: String`, `subtitle: String`, `icon: IconData` |
| Used by | `BooksScreen`, `MoviesScreen`, `PomodoroScreen`, `GymScreen` |

Centred placeholder with icon, title, subtitle displayed when a list is empty.

---

### `lib/widgets/pill.dart`
| | |
|---|---|
| Class | `Pill` (StatelessWidget) |
| Props | `text: String`, `color: Color?`, `icon: IconData?` |
| Used by | `BookCard`, `WatchItemCard`, `MovieCard` |

Small rounded label (genre tag, language badge, status indicator).

---

### `lib/widgets/water_tracker_card.dart`
| | |
|---|---|
| Class | `WaterTrackerCard` (StatefulWidget) |
| Used by | `HealthCenterScreen` |

Interactive water intake card. Wave animation rises as intake increases. Quick-add buttons (+250ml, +500ml). Long-press → goal dialog. Tap label → `WaterHistoryScreen`.

---

### `lib/widgets/daily_progress_rings.dart`
| | |
|---|---|
| Class | `DailyProgressRings` (StatelessWidget) |
| Sub-widget | `_RingsPainter` (CustomPainter) |
| Used by | `ActivitySummaryScreen`, `_ProgressTab` |

4 concentric animated progress rings: Move (calories), Exercise (active minutes), Focus (pomodoro), Habits (streak). Entrance animation via `AnimationController`.

---

### `lib/widgets/weekly_progress_card.dart`
| Used by | `_ProgressTab` |
|---|---|

Weekly summary card with day-by-day bar chart and totals.

---

### `lib/widgets/weight_card.dart`
| Used by | `HealthCenterScreen`, `BodyCompositionScreen` |
|---|---|

Compact body weight display with trend arrow.

---

### `lib/widgets/time_card.dart`
| Used by | `ActivitySummaryScreen` |
|---|---|

Small time-display card (e.g. "2h 15m active").

---

## UI Framework Widgets

### `lib/ui/app_scaffold.dart`
| | |
|---|---|
| Class | `AppScaffold` (StatelessWidget) |
| Props | `title: String`, `actions: List<Widget>?`, `child: Widget`, `accentColor: Color?` |
| Used by | Various screens, `ProtectedCountersGate` |

Standard screen wrapper: SafeArea + custom AppBar with optional coloured accent bar (2px line below title) + `Divider` at bottom.

---

### `lib/ui/shortcut_card.dart`
| | |
|---|---|
| Class | `ShortcutCard` (StatelessWidget) |
| Props | `title`, `subtitle`, `icon`, `gradient: List<Color>`, `onTap`, `trailing: Widget?` |
| Used by | `_HomeTab` |

Tall gradient card for home screen module grid. Gradient uses feature gradient pairs from `NudgeTokens`.

---

## Dead Code

The following files exist but are **never imported** by any live screen. They import `provider` which is not in `pubspec.yaml`.

| File | Class | Reason dead |
|---|---|---|
| `lib/widgets/add_card_sheet.dart` | `AddCardSheet` | Imports `provider` |
| `lib/widgets/habit_card.dart` | `HabitCard` | Duplicate — real one is in `protected/` |
| `lib/widgets/counter_card.dart` | `CounterCard` | Imports `provider` |
| `lib/widgets/light_bar.dart` | `LightBar` | Imports `provider` |
| `lib/screens/protected/protected_counters_screen.dart` | placeholder | Not implemented |

> `flutter analyze` reports errors for these files. The app builds and runs fine because they are never imported.

---

## Services & Utilities

| File | Class / exports | Role |
|---|---|---|
| `lib/storage.dart` | `AppStorage` | Hive box manager (gym, movies, books, finance, food, food_library, settings, protected, pomodoro) |
| `lib/providers/app_state.dart` | `AppState` (ChangeNotifier) | Global state (no Provider package — used with `ListenableBuilder`) |
| `lib/services/auth_service.dart` | `AuthService` | Firebase Auth + Google Sign-In wrapper |
| `lib/services/firebase_backup_service.dart` | `FirebaseBackupService` | AES-256 encrypt → Firestore backup/restore |
| `lib/services/auto_backup_service.dart` | `AutoBackupService`, `callbackDispatcher` | WorkManager nightly (2 AM) backup scheduling |
| `lib/services/health_center_service.dart` | `HealthCenterService` | Aggregates HC + GPS + manual data per day |
| `lib/services/running_coach_service.dart` | `RunningCoachService` | Cardio analytics, race predictions, training load |
| `lib/services/gps_tracking_service.dart` | `GpsTrackingService` | Live GPS tracking + session persistence |
| `lib/services/widget_service.dart` | `WidgetService` | Android home-screen widget data updates |
| `lib/services/indian_bank_sms_parser.dart` | `IndianBankSmsParser` | SMS → expense extraction (Indian banks) |
| `lib/services/update_service.dart` | `UpdateService` | APK update check + install via `MethodChannel` |
| `lib/utils/gemini_service.dart` | `GeminiService` | Gemini API calls (dual key, model selector) |
| `lib/utils/ai_analysis_service.dart` | `AiAnalysisService` | Health/fitness AI coaching reports |
| `lib/utils/ai_routine_generator.dart` | `AiRoutineGenerator` | Gym routine AI generation |
| `lib/utils/health_service.dart` | `HealthService` | Raw Health Connect data + water log |
| `lib/utils/sleep_service.dart` | `SleepService` | Sleep data read/write (HC + manual) |
| `lib/utils/food_service.dart` | `FoodService` | Food entry CRUD, macro goals, food library |
| `lib/utils/finance_service.dart` | `FinanceService` | Expense CRUD, budget, category management |
| `lib/utils/usage_service.dart` | `UsageService` | Android UsageStats API, app name/icon cache |
| `lib/utils/pomodoro_service.dart` | `PomodoroService` | Native MethodChannel (`com.example.nudge/pomodoro`) for blocker |
| `lib/utils/detox_service.dart` | `DetoxService`, `DetoxSchedule` | Background timer (30s) activates blocker when schedule active |
| `lib/utils/streak_service.dart` | `StreakService` | Habit streak calculation helpers |
| `lib/utils/notification_service.dart` | `NotificationService` | Local notifications (habits, pomodoro, reminders) |
| `lib/utils/theme_service.dart` | `ThemeService` (ChangeNotifier) | Theme switching (5 themes), persisted in settings |
| `lib/utils/nudge_theme_extension.dart` | `NudgeThemeExtension` | Flutter `ThemeExtension` for per-theme token overrides |
| `lib/utils/pdf_export_service.dart` | `PdfExportService` | PDF progress report (cover + 14-day logbook) |
| `lib/utils/date_utils.dart` | date helpers | Formatting, comparison, week-start utilities |
| `lib/utils/runtime_fetcher.dart` | `RuntimeFetcher` | App version / build number |
| `lib/export/csv_export.dart` | `CsvExport` | CSV generation for 10 data types |

### Native MethodChannels

| Channel | Handler | Methods |
|---|---|---|
| `com.example.nudge/finance` | `MainActivity.kt` | `checkPermission`, `requestPermission`, `getPendingExpenses`, `getRawNotifications`, `clearFinanceData`, `checkSmsPermission`, `requestSmsPermission`, `getSmsTransactions` |
| `com.example.nudge/pomodoro` | `MainActivity.kt` | `checkOverlayPermission`, `requestOverlayPermission`, `startBlocker`, `stopBlocker`, `getNextAlarm` |
| `com.example.nudge/update` | `MainActivity.kt` | `installApk` |
| `com.example.nudge/backup` | `MainActivity.kt` | `isBatteryOptimizationDisabled`, `openBatteryOptimizationSettings` |

---

## Full File Tree

```
lib/
├── app.dart                                ← NudgeTokens + NudgeApp (theme/auth flow)
├── main.dart                               ← Entry point (Hive, Firebase, WorkManager init)
├── storage.dart                            ← AppStorage — all Hive boxes
│
├── models/
│   ├── card_model.dart / .g.dart           ← Hive model (codegen)
│   ├── card_type.dart / .g.dart            ← CardType enum (codegen)
│   └── health_goal.dart                    ← HealthGoal data class
│
├── providers/
│   └── app_state.dart                      ← AppState ChangeNotifier
│
├── services/
│   ├── auth_service.dart
│   ├── firebase_backup_service.dart
│   ├── auto_backup_service.dart
│   ├── health_center_service.dart
│   ├── running_coach_service.dart
│   ├── gps_tracking_service.dart
│   ├── widget_service.dart
│   ├── indian_bank_sms_parser.dart
│   └── update_service.dart
│
├── utils/
│   ├── gemini_service.dart
│   ├── ai_analysis_service.dart
│   ├── ai_routine_generator.dart
│   ├── health_service.dart
│   ├── sleep_service.dart
│   ├── food_service.dart
│   ├── finance_service.dart
│   ├── usage_service.dart
│   ├── pomodoro_service.dart
│   ├── detox_service.dart
│   ├── streak_service.dart
│   ├── notification_service.dart
│   ├── theme_service.dart
│   ├── nudge_theme_extension.dart
│   ├── pdf_export_service.dart
│   ├── date_utils.dart
│   ├── runtime_fetcher.dart
│   ├── data_seeder.dart
│   └── mock_data_service.dart
│
├── export/
│   └── csv_export.dart
│
├── screens/
│   ├── home_screen.dart                    ← 4-tab shell (_HomeTab, _ProgressTab, _NudgeNavBar)
│   ├── onboarding_screen.dart              ← 11-step wizard
│   ├── settings_screen.dart               ← Settings hub
│   ├── raw_health_screen.dart             ← Debug health data
│   │
│   ├── auth/
│   │   └── sign_in_screen.dart
│   │
│   ├── onboarding/
│   │   ├── privacy_intro_screen.dart
│   │   ├── orbit_demo_screen.dart
│   │   └── restore_from_cloud_screen.dart
│   │
│   ├── protected/
│   │   ├── protected_gate.dart             ← Biometric gate
│   │   ├── protected_habits_screen.dart    ← Main PIN-locked habits
│   │   ├── habit_card.dart                 ← ★ The real HabitCard widget
│   │   ├── habit_detail_screen.dart
│   │   ├── habit_editor_sheet.dart
│   │   ├── habit_routine_card.dart
│   │   ├── mini_bar_graph.dart
│   │   ├── icon_picker_sheet.dart
│   │   ├── protected_counters_gate.dart
│   │   └── protected_counters_screen.dart  ← placeholder
│   │
│   ├── habits/
│   │   └── my_habits_screen.dart           ← Public habits (no PIN)
│   │
│   ├── trackers/
│   │   └── day_tracker_screen.dart         ← Long-form challenge tracker
│   │
│   ├── gym/
│   │   ├── gym_screen.dart                 ← Main fitness screen (~800 lines)
│   │   ├── gym_settings_screen.dart
│   │   ├── gym_progress_charts.dart
│   │   ├── gym_routines_screen.dart
│   │   ├── profile_sheet.dart
│   │   ├── exercise_detail_sheet.dart
│   │   ├── exercise_picker_sheet.dart
│   │   ├── exercise_thumbnail.dart
│   │   ├── exercise_info.dart
│   │   ├── exercise_illustration.dart
│   │   ├── muscle_mannequin.dart
│   │   ├── stickman_engine.dart
│   │   ├── workout_editor.dart
│   │   ├── gym_screen_imports.dart
│   │   ├── calories.dart
│   │   └── exercise_db.dart
│   │
│   ├── pomodoro/
│   │   ├── pomodoro_screen.dart
│   │   ├── pomodoro_stats_screen.dart
│   │   ├── pomodoro_engine.dart            ← singleton service
│   │   ├── timer_ring.dart
│   │   ├── project_editor_sheet.dart
│   │   └── manual_log_sheet.dart
│   │
│   ├── books/
│   │   ├── books_screen.dart
│   │   ├── book_card.dart
│   │   ├── book_editor_sheet.dart
│   │   └── books_stats_header.dart
│   │
│   ├── movies/
│   │   ├── movies_screen.dart
│   │   ├── movie_card.dart
│   │   ├── movie_editor_sheet.dart
│   │   ├── watch_editor_sheet.dart
│   │   ├── watch_item_card.dart
│   │   └── movies_stats_header.dart
│   │
│   ├── food/
│   │   ├── food_screen.dart
│   │   ├── add_food_sheet.dart             ← AI + barcode + image input
│   │   ├── edit_food_sheet.dart
│   │   ├── nutrition_settings_screen.dart
│   │   └── meal_selector.dart
│   │
│   ├── finance/
│   │   ├── finance_screen.dart
│   │   ├── add_expense_sheet.dart
│   │   ├── budget_editor_sheet.dart
│   │   └── raw_notification_screen.dart
│   │
│   ├── health/
│   │   ├── health_center_screen.dart       ← Main health hub
│   │   ├── sleep_screen.dart
│   │   ├── water_history_screen.dart
│   │   ├── goals_screen.dart
│   │   ├── body_composition_screen.dart
│   │   ├── analysis_report_screen.dart
│   │   ├── running_coach_list_screen.dart
│   │   └── running_coach_screen.dart
│   │
│   ├── activity/
│   │   ├── activity_summary_screen.dart    ← Unified dashboard (Tab 1)
│   │   ├── activity_tracker_screen.dart    ← GPS live tracking
│   │   └── steps_detail_screen.dart
│   │
│   ├── settings/
│   │   ├── theme_settings_screen.dart
│   │   ├── ai_error_log_screen.dart
│   │   └── developer_options_screen.dart
│   │
│   ├── digital_wellbeing/
│   │   └── digital_wellbeing_screen.dart   ← Screen Time + Detox (2 tabs)
│   │
│   └── export/
│       └── export_screen.dart
│
├── widgets/
│   ├── empty_card.dart                     ← Used widely
│   ├── pill.dart                           ← Tag/badge
│   ├── water_tracker_card.dart
│   ├── daily_progress_rings.dart
│   ├── weekly_progress_card.dart
│   ├── weight_card.dart
│   ├── time_card.dart
│   ├── movie_card.dart
│   ├── add_card_sheet.dart                 ← DEAD CODE
│   ├── habit_card.dart                     ← DEAD CODE (duplicate)
│   ├── counter_card.dart                   ← DEAD CODE
│   └── light_bar.dart                      ← DEAD CODE
│
└── ui/
    ├── app_scaffold.dart                   ← Standard screen wrapper
    └── shortcut_card.dart                  ← Home grid module card
```
