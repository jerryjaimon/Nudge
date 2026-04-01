# Nudge — Change Log

---

## 2026-03-24 (session 2)

### Screen Time — weekly inline day view
- **Weekly view no longer jumps to Daily**: tapping a bar in the weekly chart now highlights the bar and shows that day's app cards inline (within the weekly view), with a "Full Day →" link to switch to the full daily view.

### Screen Time — app tracking
- **Track Apps button** (filter icon in header): opens `_AppTrackerSheet` — a searchable list of all installed apps where the user selects apps to highlight.
- **Daily hero card** now shows `TRACKED | TOTAL` stat cells when tracked apps are configured; falls back to `STATUS | DAILY GOAL` when none are set.
- **Daily view split into two sections**: "TRACKED APPS" (blue label) and "OTHER APPS" when tracked apps are set; single "TODAY'S APPS" section when none are configured.

### Food Tracker — previous-day date fix
- **Fixed**: adding food while viewing a previous day now saves to that day instead of today.
- `AddFoodSheet` accepts a new `date` parameter; all three call sites in `food_screen.dart` now pass `_currentDate`.
- `FoodService.saveEntry` timestamp is set from the passed date when provided.

---

## 2026-03-24

### Digital Wellbeing — Screen Time overhaul
- **Fixed screen time count bug**: query now starts at midnight of the selected day instead of "24 hours ago", which was spanning two calendar days and doubling reported usage.
- **Daily / Weekly toggle**: Screen Time tab now has two distinct views — Daily and Weekly — accessed via toggle chips.
- **Daily view**: date navigation (← / →) with TODAY chip to jump back, hero stats card, per-app list.
- **Weekly view**: tappable 7-day bar chart (tap a bar to jump to that day's Daily view), weekly stats strip (total, avg/day, peak day), top apps ranked by week usage with 7-day mini bars.
- **App tiles redesigned**: now use calorie-card template (matching Health Center) with big time number, 8px progress bar, "this week" and "avg/day" stat cells at the bottom.
- **App detail page** (`AppDetailScreen`): tap any app tile to open a full-screen breakdown with selected-day usage, 3-stat header (week total, avg/day, peak day), 7-day bar chart, and daily breakdown list for the last 7 days.
- Removed inline per-app 7-day expansion (replaced by dedicated detail page).

### Digital Wellbeing — Detox overhaul
- **Detox empty state**: replaced plain empty state with a motivating 🌿 page containing tip cards (Night Mode, Deep Work, Stay Consistent) and streak-building encouragement.
- **Active Now badge**: schedule tiles show a green "Active Now" badge and shield icon when the schedule is currently in its time window — clarifies that the Pomodoro-based blocker is working as intended.
- **Active blocking banner** (🛡️): a "Shield is active!" banner appears at the top of the Detox tab when any schedule is blocking right now.
- Schedule tiles highlight with a green border when active.

---

## 2026-03-23

### Health Center
- **Day Boundary** setting greyed out (opacity 0.45, tap disabled, "Coming Soon" badge) — feature not yet ready.

### Digital Wellbeing — Merge
- **Detox + Screen Time merged** into a single `DigitalWellbeingScreen` with two tabs: Screen Time and Detox.
- Home screen "Detox" card updated to open `DigitalWellbeingScreen`.
- Settings > Digital Detox now navigates to `DigitalWellbeingScreen(initialTab: 1)`.
- Screen Time card on home screen also navigates to `DigitalWellbeingScreen`.
- Added `UsageService.fetchDayStats(date)` — correct midnight-to-midnight query returning `Map<String, int>`.
- Added `UsageService.formatDurationMs(int ms)` helper.
