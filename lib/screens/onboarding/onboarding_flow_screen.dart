// lib/screens/onboarding/onboarding_flow_screen.dart
//
// Full 12-step onboarding wizard for Nudge.
// Covers: Intro → Sign-In → AI Setup → About You → Goals → Activity →
//         Schedule → Workout Import → Calorie/Hydration → Finance →
//         Modules → AI Plan Generation.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart' show NudgeTokens;
import '../../services/auth_service.dart';
import '../../services/health_center_service.dart';
import '../../storage.dart';
import '../../utils/gemini_service.dart';
import '../../widgets/orbit_animation.dart';
import '../home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root widget
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  static const int _totalPages = 12;

  // ── Collected data ──────────────────────────────────────────────────────────
  // Step 2 – AI
  String _geminiKey = '';
  bool _geminiValidated = false;

  // Step 0 — sign-in (merged with intro)
  bool _signInLoading = false;
  bool _signedIn = false;
  String? _signInError;

  // Step 3 – About You
  String _name = '';
  int _age = 25;
  String _gender = 'Male';
  double _heightCm = 170;
  String _weightKgText = '70';
  bool _aboutYouSkipped = false;

  // Step 4 – Goals
  final Set<String> _selectedGoals = {};
  String _goalDescription = '';

  // Step 5 – Activity
  String _activityLevel = 'Intermediate';
  final Set<String> _activityTypes = {};
  String _currentRoutineText = '';

  // Step 6 – Schedule
  final Set<int> _workoutDays = {}; // 0=Mon … 6=Sun
  double _sessionMinutes = 60;
  String _scheduleNotes = '';

  // Step 7 – Workout Import
  final List<XFile> _workoutImages = [];
  String _youtubeLinks = '';

  // Step 8 – Calorie & Hydration
  bool _dynamicTargets = false;
  double _calorieGoal = 2000;
  double _waterGoalMl = 2500;
  double _calorieAdjPer100 = 1.0;

  // Step 9 – Finance
  String _monthlyIncome = '';
  String _monthlyBudget = '1500';
  double _savingsPct = 10;
  String _currency = '£';

  // Step 10 – Modules
  final Map<String, bool> _modules = {
    'Gym & Fitness': true,
    'Food & Nutrition': true,
    'Finance': true,
    'Movies': true,
    'Books': true,
    'Pomodoro': true,
    'Protected Habits': true,
    'Digital Detox': true,
  };

  // Step 7 – Extracted workout
  String _extractedWorkout = '';

  // Step 11 – Fitness Plan
  String? _fitnessPlan;
  bool _fitnessPlanGenerating = false;
  String? _fitnessPlanError;
  String _fitnessPlanNotes = '';
  int _fitnessStatusIdx = 0;
  Timer? _fitnessStatusTimer;

  // Goal safety validation (AI)
  List<String> _aiSafetyWarnings = [];
  bool _aiSafetyChecking = false;

  // Step 12 – Finance Plan
  String? _financePlan;
  bool _financePlanGenerating = false;
  String? _financePlanError;
  String _debtAmount = '';
  String _investmentGoal = '';
  bool _aiFinanceEnabled = true;
  int _financeStatusIdx = 0;
  Timer? _financeStatusTimer;

  // ── Navigation helpers ──────────────────────────────────────────────────────

  Future<void> _googleSignIn() async {
    setState(() { _signInLoading = true; _signInError = null; });
    try {
      final user = await AuthService.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        setState(() { _signedIn = true; _signInLoading = false; });
      } else {
        setState(() => _signInLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() { _signInError = e.toString(); _signInLoading = false; });
    }
  }

  void _goTo(int page) {
    _pageCtrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentPage = page);
  }

  void _next() {
    // Leaving workout import (page 6) → entering fitness plan (page 7)
    // Kick off AI goal safety check in background
    if (_currentPage == 6) {
      _checkGoalSafety();
    }
    // Leaving fitness plan (page 7) → entering calorie/hydration (page 8)
    if (_currentPage == 7) {
      final tdee = _calculateTDEE();
      final water = _recommendedWaterMl();
      if (_calorieGoal == 2000) setState(() => _calorieGoal = tdee.clamp(1200.0, 4000.0));
      if (_waterGoalMl == 2500) setState(() => _waterGoalMl = water);
    }
    _goTo(_currentPage + 1);
  }
  void _back() => _goTo(_currentPage - 1);

  void _skipToHome() {
    AppStorage.hasSeenOnboarding = true;
    AppStorage.settingsBox.put('allow_offline', true);
    _navigateHome();
  }

  void _navigateHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    // Persist all collected data
    final box = AppStorage.settingsBox;

    box.put('onboarding_name', _name);
    box.put('onboarding_age', _age);
    box.put('onboarding_height', _heightCm);
    box.put('onboarding_weight', double.tryParse(_weightKgText) ?? 70.0);
    box.put('onboarding_gender', _gender);
    box.put('onboarding_goals', _selectedGoals.toList());
    box.put('onboarding_workout_days', _workoutDays.toList());
    box.put('onboarding_budget', double.tryParse(_monthlyBudget) ?? 1500.0);
    box.put('onboarding_currency', _currency);
    box.put('onboarding_calorie_goal', _calorieGoal.round());
    box.put('onboarding_water_goal', _waterGoalMl.round());
    box.put('onboarding_dynamic_targets', _dynamicTargets);

    // Gemini key
    if (_geminiKey.isNotEmpty) {
      box.put('gemini_api_key_1', _geminiKey);
    }

    // Health profile
    await HealthCenterService.saveProfile({
      'name': _name,
      'age': _age,
      'heightCm': _heightCm,
      'weightKg': double.tryParse(_weightKgText) ?? 70.0,
      'gender': _gender.toLowerCase(),
      'goal': _primaryGoalKey(),
      'activityLevel': _activityLevelKey(),
    });

    // Cardio goals
    await HealthCenterService.saveCardioGoals(
      steps: 8000,
      caloriesBurned: _calorieGoal.round(),
      weeklyWorkouts: _workoutDays.length,
    );

    // Modules — map display names to storage IDs
    const moduleKeyMap = {
      'Gym & Fitness': 'gym',
      'Food & Nutrition': 'food',
      'Finance': 'finance',
      'Movies': 'movies',
      'Books': 'books',
      'Pomodoro': 'pomodoro',
      'Protected Habits': 'habits',
      'Digital Detox': 'detox',
    };
    // Always include health + my_habits
    final enabledModules = <String>['health', 'my_habits'];
    for (final e in _modules.entries) {
      if (e.value) {
        final id = moduleKeyMap[e.key];
        if (id != null && !enabledModules.contains(id)) {
          enabledModules.add(id);
        }
      }
    }
    box.put('enabled_modules', enabledModules);

    // Budget / currency
    box.put('fin_monthly_budget', double.tryParse(_monthlyBudget) ?? 1500.0);
    box.put('fin_currency', _currency);
    if (_monthlyIncome.isNotEmpty) {
      box.put('fin_monthly_income', double.tryParse(_monthlyIncome) ?? 0.0);
    }
    if (_debtAmount.isNotEmpty) {
      box.put('fin_monthly_debt', double.tryParse(_debtAmount) ?? 0.0);
    }
    if (_investmentGoal.isNotEmpty) {
      box.put('fin_investment_goal', _investmentGoal);
    }
    if (_fitnessPlan != null) box.put('ai_fitness_plan', _fitnessPlan);
    if (_financePlan != null) box.put('ai_finance_plan', _financePlan);

    // Workout schedule — save selected days to gymBox so gym screen can use them
    final gymBox = await AppStorage.getGymBox();
    // _workoutDays uses 0=Mon…6=Sun; schedule keys are '1'=Mon…'7'=Sun (weekday)
    final schedule = <String, String>{};
    for (int i = 0; i < 7; i++) {
      schedule[(i + 1).toString()] =
          _workoutDays.contains(i) ? 'workout' : 'rest';
    }
    await gymBox.put('workout_schedule', schedule);
    if (_fitnessPlan != null) {
      await gymBox.put('ai_plan_text', _fitnessPlan);
    }

    AppStorage.hasSeenOnboarding = true;
    AppStorage.settingsBox.put('allow_offline', true);
    _navigateHome();
  }

  // ── TDEE & hydration helpers ─────────────────────────────────────────────

  double _calculateTDEE() {
    final weight = double.tryParse(_weightKgText) ?? 70.0;
    double bmr;
    if (_gender == 'Male') {
      bmr = 88.362 + (13.397 * weight) + (4.799 * _heightCm) - (5.677 * _age);
    } else {
      bmr = 447.593 + (9.247 * weight) + (3.098 * _heightCm) - (4.330 * _age);
    }
    const multipliers = {'Beginner': 1.375, 'Intermediate': 1.55, 'Advanced': 1.725};
    return bmr * (multipliers[_activityLevel] ?? 1.55);
  }

  double _recommendedWaterMl() {
    final weight = double.tryParse(_weightKgText) ?? 70.0;
    return (weight * 35).clamp(1500.0, 4000.0);
  }

  String _primaryGoalKey() {
    if (_selectedGoals.contains('Build Muscle')) return 'gain';
    if (_selectedGoals.contains('Lose Weight')) return 'lose';
    return 'maintain';
  }

  String _activityLevelKey() {
    switch (_activityLevel) {
      case 'Beginner':
        return 'light';
      case 'Advanced':
        return 'very_active';
      default:
        return 'moderate';
    }
  }

  // ── AI Plan ─────────────────────────────────────────────────────────────────

  static const _statusMessages = [
    'Analysing your profile…',
    'Setting your targets…',
    'Crafting your schedule…',
    'Almost there…',
  ];


  List<String> _computeFitnessWarnings() {
    final warnings = <String>[];
    final weight = double.tryParse(_weightKgText) ?? 70.0;
    final heightM = _heightCm / 100;
    final bmi = weight / (heightM * heightM);
    final cals = _calorieGoal;
    final desc = '$_goalDescription ${_selectedGoals.join(' ')}'.toLowerCase();

    // ── Calorie safety ──────────────────────────────────────────────────────
    if (_gender == 'Female' && cals < 1200) {
      warnings.add('⚠ Calorie goal below 1200 kcal is dangerous. Minimum recommended for women is 1400–1600 kcal/day.');
    } else if (_gender == 'Male' && cals < 1500) {
      warnings.add('⚠ Calorie goal below 1500 kcal is very restrictive. Minimum recommended for men is 1800 kcal/day.');
    }

    // ── Workout volume ───────────────────────────────────────────────────────
    if (_workoutDays.length == 7) {
      warnings.add('🚨 Training every single day with no rest days causes overtraining syndrome, injury, and hormonal disruption. At least 1 rest day is medically essential.');
    } else if (_workoutDays.length >= 6) {
      warnings.add('⚠ 6 workout days per week is very demanding. Prioritise sleep (8+ hours) and active recovery on rest days.');
    }

    // ── Session length ───────────────────────────────────────────────────────
    if (_activityLevel == 'Beginner' && _sessionMinutes > 75) {
      warnings.add('⚠ For beginners, sessions over 60–75 min cause excessive fatigue and increase injury risk. Start at 45–60 min.');
    }

    // ── BMI extremes ─────────────────────────────────────────────────────────
    if (bmi < 17.0) {
      warnings.add('🚨 Your BMI (${bmi.toStringAsFixed(1)}) indicates severe underweight. Please consult a healthcare provider before any exercise programme.');
    } else if (bmi > 35 && _selectedGoals.contains('Lose Weight')) {
      warnings.add('⚠ BMI > 35 with weight-loss goals: medical supervision is strongly recommended before starting exercise.');
    }

    // ── Parse goal description for dangerous weight-loss rates ───────────────
    final wlMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:kg|kilograms?|pounds?|lbs?)\s*(?:in|within|over)\s*(\d+)\s*(week|month)',
    ).firstMatch(desc);
    if (wlMatch != null) {
      final amount = double.tryParse(wlMatch.group(1) ?? '0') ?? 0;
      final time = int.tryParse(wlMatch.group(2) ?? '1') ?? 1;
      final unit = wlMatch.group(3) ?? 'month';
      final weeksEquiv = unit.startsWith('month') ? time * 4.33 : time.toDouble();
      final kgPerWeek = amount / weeksEquiv;
      if (kgPerWeek > 1.0) {
        warnings.add(
          '🚨 DANGEROUS GOAL DETECTED: "${amount.toStringAsFixed(0)} kg in $time ${unit}s" requires losing '
          '${kgPerWeek.toStringAsFixed(1)} kg/week. The safe maximum is 0.5–1 kg/week. '
          'This rate causes severe muscle loss, nutritional deficiencies, metabolic damage, and potentially organ failure.',
        );
      }
    }

    // ── Parse goal description for impossible running paces ──────────────────
    final runMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*k(?:m|ilometre).*?(?:in|under|within)\s*(\d+)\s*min',
    ).firstMatch(desc);
    if (runMatch != null) {
      final km = double.tryParse(runMatch.group(1) ?? '0') ?? 0;
      final mins = double.tryParse(runMatch.group(2) ?? '99') ?? 99;
      if (km > 0 && (mins / km) < 3.0) {
        warnings.add(
          '🚨 IMPOSSIBLE GOAL DETECTED: ${km}km in ${mins.toStringAsFixed(0)} min is '
          '${(mins / km).toStringAsFixed(1)} min/km pace. The 5km world record is ~12:35 (2.5 min/km). '
          'This pace is physically impossible and indicates a data entry error — please correct your goal.',
        );
      } else if (km > 0 && (mins / km) < 4.5 && _activityLevel == 'Beginner') {
        warnings.add(
          '⚠ ${km}km in ${mins.toStringAsFixed(0)} min requires elite-level running fitness. '
          'As a beginner, this is likely a long-term goal, not a starting target.',
        );
      }
    }

    return warnings;
  }

  Future<void> _checkGoalSafety() async {
    if (AppStorage.activeGeminiKey.isEmpty) return;
    if (_goalDescription.isEmpty && _selectedGoals.isEmpty) return;
    setState(() { _aiSafetyChecking = true; _aiSafetyWarnings = []; });

    try {
      final result = await GeminiService.generate(
        prompt: '''You are a certified fitness professional and medical safety expert.
Analyse these fitness goals ONLY for dangerous or physically impossible targets.
Do NOT include general advice. Only flag genuine health risks or physically impossible claims.

GOALS: ${_selectedGoals.join(', ')}
DESCRIPTION: "${_goalDescription.isEmpty ? 'none' : _goalDescription}"
PROFILE: Age $_age, ${_weightKgText}kg, ${_heightCm.round()}cm, $_activityLevel

Return ONLY a JSON array of warning strings. Return [] if everything is safe.
Example: ["Losing 2.5 kg/week is dangerous — safe max is 0.5–1 kg/week"]''',
      );
      if (result != null && mounted) {
        final match = RegExp(r'\[.*?\]', dotAll: true).firstMatch(result);
        if (match != null) {
          final warnings = RegExp(r'"([^"]+)"')
              .allMatches(match.group(0)!)
              .map((m) => '🤖 AI: ${m.group(1)!}')
              .where((s) => s.isNotEmpty)
              .toList();
          if (warnings.isNotEmpty && mounted) {
            setState(() => _aiSafetyWarnings = warnings);
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _aiSafetyChecking = false);
    }
  }

  Future<void> _generateFitnessPlan() async {
    if (_fitnessPlanGenerating) return;
    setState(() {
      _fitnessPlanGenerating = true;
      _fitnessPlanError = null;
      _fitnessStatusIdx = 0;
    });

    _fitnessStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _fitnessStatusIdx = (_fitnessStatusIdx + 1) % _statusMessages.length);
    });

    final key = AppStorage.activeGeminiKey;
    if (key.isEmpty) {
      _fitnessStatusTimer?.cancel();
      if (mounted) setState(() {
        _fitnessPlanError = 'No Gemini API key set. Add one in Settings → AI.';
        _fitnessPlanGenerating = false;
      });
      return;
    }

    final workoutSection = _extractedWorkout.isNotEmpty
        ? '\nIMPORTED WORKOUT DATA:\n$_extractedWorkout\n'
        : '';
    final restDays = List.generate(7, (i) => i)
        .where((i) => !_workoutDays.contains(i))
        .map((i) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i])
        .join(', ');
    final notes = _fitnessPlanNotes.isNotEmpty
        ? '\nUSER ADJUSTMENTS: $_fitnessPlanNotes\n'
        : '';

    final prompt = '''
You are a certified personal trainer and sports nutritionist. Create a detailed, safe, and realistic fitness plan. Do NOT include the user's name.

USER PROFILE:
- Age: $_age | Gender: $_gender
- Height: ${_heightCm.round()} cm | Weight: $_weightKgText kg
- Activity Level: $_activityLevel
- Activity Types: ${_activityTypes.isEmpty ? 'Not specified' : _activityTypes.join(', ')}
- Goals: ${_selectedGoals.isEmpty ? 'Not specified' : _selectedGoals.join(', ')}
- Workout Days: ${_workoutDays.map((d) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d]).join(', ')}
- Rest Days: ${restDays.isEmpty ? 'None' : restDays}
- Session Length: ${_sessionMinutes.round()} minutes
- Calorie Goal: ${_calorieGoal.round()} kcal/day
- Water Goal: ${_waterGoalMl.round()} ml/day
$workoutSection$notes

Please provide:
## 7-Day Workout Schedule
(For each workout day: exercises, sets, reps, rest between sets)

## Progressive Overload Plan
(Weeks 2–4 progression suggestions)

## Nutrition Timing
(Pre/post workout meals, timing guidance)

## Recovery & Sleep Tips
(Specific to their activity level and goals)

Keep each section concise and practical. Use markdown formatting.
''';

    try {
      final result = await GeminiService.generate(prompt: prompt);
      _fitnessStatusTimer?.cancel();
      if (mounted) {
        setState(() {
          _fitnessPlan = result;
          _fitnessPlanGenerating = false;
        });
      }
    } catch (e) {
      _fitnessStatusTimer?.cancel();
      if (mounted) setState(() {
        _fitnessPlanError = 'Generation failed: $e';
        _fitnessPlanGenerating = false;
      });
    }
  }

  Future<void> _generateFinancePlan() async {
    if (_financePlanGenerating || !_aiFinanceEnabled) return;
    setState(() {
      _financePlanGenerating = true;
      _financePlanError = null;
      _financeStatusIdx = 0;
    });

    _financeStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _financeStatusIdx = (_financeStatusIdx + 1) % _statusMessages.length);
    });

    final key = AppStorage.activeGeminiKey;
    if (key.isEmpty) {
      _financeStatusTimer?.cancel();
      if (mounted) setState(() {
        _financePlanError = 'No Gemini API key set. Add one in Settings → AI.';
        _financePlanGenerating = false;
      });
      return;
    }

    final income = double.tryParse(_monthlyIncome) ?? 0.0;
    final budget = double.tryParse(_monthlyBudget) ?? 1500.0;
    final debt = double.tryParse(_debtAmount) ?? 0.0;
    final investGoal = _investmentGoal.isNotEmpty ? _investmentGoal : 'Not specified';

    final prompt = '''
You are a certified financial planner. Create a personalised financial plan. Do NOT include the user's name. Add a disclaimer that this is educational content, not regulated financial advice.

FINANCIAL PROFILE:
- Monthly Income: ${income > 0 ? '$_currency${income.toStringAsFixed(0)}' : 'Not provided'}
- Monthly Spending Budget: $_currency$budget
- Savings Target: ${_savingsPct.round()}% of income
- Monthly Debt Repayments: ${debt > 0 ? '$_currency${debt.toStringAsFixed(0)}' : 'None'}
- Investment Goal: $investGoal
- Currency: $_currency
- Goals: ${_selectedGoals.isEmpty ? 'General financial wellness' : _selectedGoals.join(', ')}

Provide:
## Budget Breakdown
(Apply 50/30/20 or an appropriate framework. Show the maths.)

## Savings Strategy
(Emergency fund, short-term, long-term)

## Debt Reduction Plan
(If applicable — avalanche or snowball method)

## Investment Starting Points
(Low-risk, framework-based suggestions appropriate for their goal)

## 30-Day Action Plan
(5 concrete steps to take immediately)

## Disclaimer
(Regulatory disclaimer — not personal financial advice)

Use markdown. Keep each section practical.
''';

    try {
      final result = await GeminiService.generate(prompt: prompt);
      _financeStatusTimer?.cancel();
      if (mounted) {
        setState(() {
          _financePlan = result;
          _financePlanGenerating = false;
        });
      }
    } catch (e) {
      _financeStatusTimer?.cancel();
      if (mounted) setState(() {
        _financePlanError = 'Generation failed: $e';
        _financePlanGenerating = false;
      });
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fitnessStatusTimer?.cancel();
    _financeStatusTimer?.cancel();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar (hidden on step 0)
            if (_currentPage > 0)
              _ProgressBar(current: _currentPage, total: _totalPages),

            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Step0Intro(
                    signedIn: _signedIn,
                    loading: _signInLoading,
                    error: _signInError,
                    onSignIn: _googleSignIn,
                    onGetStarted: _next,
                    onSkip: _skipToHome,
                  ),
                  _Step2AiSetup(
                    apiKey: _geminiKey,
                    validated: _geminiValidated,
                    onKeyChanged: (k) => setState(() {
                      _geminiKey = k;
                      _geminiValidated = false;
                    }),
                    onValidated: () => setState(() => _geminiValidated = true),
                    onNext: _next,
                    onSkip: _next,
                    onBack: _back,
                  ),
                  _Step3AboutYou(
                    name: _name,
                    age: _age,
                    gender: _gender,
                    heightCm: _heightCm,
                    weightKgText: _weightKgText,
                    onNameChanged: (v) => setState(() => _name = v),
                    onAgeChanged: (v) => setState(() => _age = v),
                    onGenderChanged: (v) => setState(() => _gender = v),
                    onHeightChanged: (v) => setState(() => _heightCm = v),
                    onWeightChanged: (v) => setState(() => _weightKgText = v),
                    onNext: _next,
                    onBack: _back,
                    onSkip: () {
                      setState(() {
                        _aboutYouSkipped = true;
                        _modules['Gym & Fitness'] = false;
                        _modules['Food & Nutrition'] = false;
                      });
                      _next();
                    },
                  ),
                  _Step4Goals(
                    selectedGoals: _selectedGoals,
                    description: _goalDescription,
                    onToggleGoal: (g) => setState(() {
                      if (_selectedGoals.contains(g)) {
                        _selectedGoals.remove(g);
                      } else {
                        _selectedGoals.add(g);
                      }
                    }),
                    onDescriptionChanged: (v) =>
                        setState(() => _goalDescription = v),
                    onNext: _next,
                    onBack: _back,
                  ),
                  _Step5Activity(
                    activityLevel: _activityLevel,
                    activityTypes: _activityTypes,
                    currentRoutine: _currentRoutineText,
                    onLevelChanged: (v) =>
                        setState(() => _activityLevel = v),
                    onToggleType: (t) => setState(() {
                      if (_activityTypes.contains(t)) {
                        _activityTypes.remove(t);
                      } else {
                        _activityTypes.add(t);
                      }
                    }),
                    onRoutineChanged: (v) =>
                        setState(() => _currentRoutineText = v),
                    onNext: _next,
                    onBack: _back,
                  ),
                  _Step6Schedule(
                    workoutDays: _workoutDays,
                    sessionMinutes: _sessionMinutes,
                    scheduleNotes: _scheduleNotes,
                    onToggleDay: (d) => setState(() {
                      if (_workoutDays.contains(d)) {
                        _workoutDays.remove(d);
                      } else {
                        _workoutDays.add(d);
                      }
                    }),
                    onSessionMinutesChanged: (v) =>
                        setState(() => _sessionMinutes = v),
                    onNotesChanged: (v) => setState(() => _scheduleNotes = v),
                    onNext: _next,
                    onBack: _back,
                  ),
                  _Step7WorkoutImport(
                    images: _workoutImages,
                    workoutDescription: _youtubeLinks,
                    hasKey: AppStorage.activeGeminiKey.isNotEmpty,
                    onImagesAdded: (imgs) =>
                        setState(() => _workoutImages.addAll(imgs)),
                    onDescriptionChanged: (v) => setState(() => _youtubeLinks = v),
                    onWorkoutExtracted: (v) => setState(() => _extractedWorkout = v),
                    onNext: _next,
                    onSkip: _next,
                    onBack: _back,
                  ),
                  // Step 7 → Fitness Plan (AI) — right after fitness inputs
                  _Step11FitnessPlan(
                    generating: _fitnessPlanGenerating,
                    plan: _fitnessPlan,
                    error: _fitnessPlanError,
                    warnings: [..._computeFitnessWarnings(), ..._aiSafetyWarnings],
                    safetyChecking: _aiSafetyChecking,
                    statusMessage: _statusMessages[_fitnessStatusIdx],
                    hasKey: AppStorage.activeGeminiKey.isNotEmpty,
                    notes: _fitnessPlanNotes,
                    onNotesChanged: (v) => setState(() => _fitnessPlanNotes = v),
                    onGenerate: _generateFitnessPlan,
                    onNext: _next,
                    onBack: _back,
                  ),
                  // Step 8 → Calorie/Hydration — now informed by fitness plan
                  _Step8CalorieHydration(
                    dynamicTargets: _dynamicTargets,
                    calorieGoal: _calorieGoal,
                    waterGoalMl: _waterGoalMl,
                    calorieAdjPer100: _calorieAdjPer100,
                    tdeeCalc: _calculateTDEE().round(),
                    recommendedWater: _recommendedWaterMl().round(),
                    fitnessPlan: _fitnessPlan,
                    hasKey: AppStorage.activeGeminiKey.isNotEmpty,
                    onDynamicChanged: (v) =>
                        setState(() => _dynamicTargets = v),
                    onCalorieChanged: (v) => setState(() => _calorieGoal = v),
                    onWaterChanged: (v) => setState(() => _waterGoalMl = v),
                    onAdjChanged: (v) =>
                        setState(() => _calorieAdjPer100 = v),
                    onNext: _next,
                    onBack: _back,
                  ),
                  _Step9Finance(
                    monthlyIncome: _monthlyIncome,
                    monthlyBudget: _monthlyBudget,
                    savingsPct: _savingsPct,
                    currency: _currency,
                    onIncomeChanged: (v) => setState(() => _monthlyIncome = v),
                    onBudgetChanged: (v) => setState(() => _monthlyBudget = v),
                    onSavingsChanged: (v) => setState(() => _savingsPct = v),
                    onCurrencyChanged: (v) => setState(() => _currency = v),
                    onNext: _next,
                    onBack: _back,
                  ),
                  _Step10Modules(
                    modules: _modules,
                    onToggle: (k, v) => setState(() => _modules[k] = v),
                    onNext: _next,
                    onBack: _back,
                  ),
                  _Step12FinancePlan(
                    generating: _financePlanGenerating,
                    plan: _financePlan,
                    error: _financePlanError,
                    statusMessage: _statusMessages[_financeStatusIdx],
                    hasKey: AppStorage.activeGeminiKey.isNotEmpty || _geminiKey.isNotEmpty,
                    aiEnabled: _aiFinanceEnabled,
                    debtAmount: _debtAmount,
                    investmentGoal: _investmentGoal,
                    monthlyIncome: _monthlyIncome,
                    monthlyBudget: _monthlyBudget,
                    savingsPct: _savingsPct,
                    currency: _currency,
                    onAiEnabledChanged: (v) => setState(() => _aiFinanceEnabled = v),
                    onDebtChanged: (v) => setState(() => _debtAmount = v),
                    onInvestmentGoalChanged: (v) => setState(() => _investmentGoal = v),
                    onGenerate: _generateFinancePlan,
                    onDone: _completeOnboarding,
                    onBack: _back,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: current / (total - 1),
          backgroundColor: NudgeTokens.border,
          valueColor:
              const AlwaysStoppedAnimation<Color>(NudgeTokens.purple),
          minHeight: 3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

TextStyle _titleStyle() => GoogleFonts.outfit(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: NudgeTokens.textHigh,
    );

TextStyle _subtitleStyle() => GoogleFonts.outfit(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: NudgeTokens.textMid,
    );

TextStyle _labelStyle() => GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: NudgeTokens.textMid,
    );

InputDecoration _inputDec(String label, {String? hint, Widget? suffix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      labelStyle: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 13),
      hintStyle: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 13),
      filled: true,
      fillColor: NudgeTokens.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NudgeTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NudgeTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: NudgeTokens.purple, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

/// Shared bottom-action area with optional back arrow, primary button, and
/// optional skip link.
Widget _bottomActions({
  required String nextLabel,
  required VoidCallback onNext,
  String? skipLabel,
  VoidCallback? onSkip,
  bool showBack = true,
  VoidCallback? onBack,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (showBack && onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: NudgeTokens.textMid, size: 20),
                onPressed: onBack,
              )
            else
              const SizedBox(width: 48),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: NudgeTokens.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(nextLabel,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
        if (skipLabel != null && onSkip != null)
          TextButton(
            onPressed: onSkip,
            child: Text(skipLabel,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: NudgeTokens.textLow,
                    fontWeight: FontWeight.w500)),
          ),
      ],
    ),
  );
}

Widget _stepHeader(String title, String subtitle) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle()),
          const SizedBox(height: 6),
          Text(subtitle, style: _subtitleStyle()),
        ],
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Step 0 — Intro
// ─────────────────────────────────────────────────────────────────────────────

class _Step0Intro extends StatelessWidget {
  final bool signedIn;
  final bool loading;
  final String? error;
  final VoidCallback onSignIn;
  final VoidCallback onGetStarted;
  final VoidCallback onSkip;
  const _Step0Intro({
    required this.signedIn,
    required this.loading,
    required this.error,
    required this.onSignIn,
    required this.onGetStarted,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Orbit animation — fills most of screen
            Expanded(
              flex: 6,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.9,
                        colors: [
                          NudgeTokens.purple.withValues(alpha: 0.05),
                          NudgeTokens.bg,
                        ],
                      ),
                    ),
                  ),
                  const OrbitAnimation(size: 300),
                  // Signed-in badge (top right)
                  if (signedIn)
                    Positioned(
                      top: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: NudgeTokens.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: NudgeTokens.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: NudgeTokens.green, size: 13),
                            const SizedBox(width: 5),
                            Text('Signed in', style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.green, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Branding below animation ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('NUDGE', style: GoogleFonts.outfit(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 8)),
                  const SizedBox(height: 6),
                  Text('Health · Finance · Discipline', style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textLow, letterSpacing: 2)),
                ],
              ),
            ),

            // Bottom sign-in + action panel
            Container(
              decoration: BoxDecoration(
                color: NudgeTokens.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: NudgeTokens.borderHi)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!signedIn) ...[
                    // Google sign-in
                    if (loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(color: NudgeTokens.purple, strokeWidth: 2),
                        ),
                      )
                    else
                      _IntroSignInButton(onTap: onSignIn),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(error!, textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.red)),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: Divider(color: NudgeTokens.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textLow)),
                        ),
                        Expanded(child: Divider(color: NudgeTokens.border)),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  FilledButton(
                    onPressed: onGetStarted,
                    style: FilledButton.styleFrom(
                      backgroundColor: signedIn ? NudgeTokens.purple : NudgeTokens.elevated,
                      side: signedIn ? null : const BorderSide(color: NudgeTokens.borderHi),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      signedIn ? 'Set up Nudge →' : 'Continue without account',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: signedIn ? Colors.white : NudgeTokens.textMid,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onSkip,
                    child: Text('Skip setup entirely',
                        style: GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.textLow)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const _IntroSignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: NudgeTokens.elevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NudgeTokens.borderHi),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MiniGoogleLogo(),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: NudgeTokens.textHigh),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniGoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20, height: 20,
      child: CustomPaint(painter: _GoogleLogoPainterOnboarding()),
    );
  }
}

class _GoogleLogoPainterOnboarding extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final segs = [
      (const Color(0xFF4285F4), -10.0, 100.0),
      (const Color(0xFF34A853), 90.0, 90.0),
      (const Color(0xFFFBBC05), 180.0, 80.0),
      (const Color(0xFFEA4335), 260.0, 110.0),
    ];
    for (final s in segs) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.7),
        s.$2 * 3.14159 / 180, s.$3 * 3.14159 / 180, false,
        Paint()..color = s.$1..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(c.dx - r * 0.05, c.dy - r * 0.18, r * 0.9, r * 0.36),
      Paint()..color = Colors.white,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — AI Setup
// ─────────────────────────────────────────────────────────────────────────────

class _Step2AiSetup extends StatefulWidget {
  final String apiKey;
  final bool validated;
  final ValueChanged<String> onKeyChanged;
  final VoidCallback onValidated;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const _Step2AiSetup({
    required this.apiKey,
    required this.validated,
    required this.onKeyChanged,
    required this.onValidated,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
  });

  @override
  State<_Step2AiSetup> createState() => _Step2AiSetupState();
}

class _Step2AiSetupState extends State<_Step2AiSetup> {
  late final TextEditingController _ctrl;
  bool _obscure = true;
  bool _validating = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing stored key if any
    final stored = AppStorage.settingsBox
        .get('gemini_api_key_1', defaultValue: '') as String;
    _ctrl = TextEditingController(text: widget.apiKey.isNotEmpty ? widget.apiKey : stored);
    if (stored.isNotEmpty && widget.apiKey.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onKeyChanged(stored);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) return;
    widget.onKeyChanged(key);
    setState(() { _validating = true; _validationError = null; });

    final ok = await GeminiService.validateKey(key, 'gemini-2.5-flash');
    if (!mounted) return;
    if (ok) {
      // Save immediately so GeminiService can use it during onboarding
      await AppStorage.settingsBox.put('gemini_api_key_1', key);
      widget.onValidated();
      setState(() => _validating = false);
    } else {
      setState(() {
        _validating = false;
        _validationError = 'Key invalid or quota exceeded. Check and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 36),
                // icon circle
                Center(child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: NudgeTokens.purple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: NudgeTokens.purple, size: 26),
                )),
                const SizedBox(height: 16),
                Text('AI Brain', style: _titleStyle(), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('Gemini powers smart nudges, workout analysis & progression plans',
                  textAlign: TextAlign.center, style: _subtitleStyle()),
                const SizedBox(height: 28),
                // text field
                TextField(
                  controller: _ctrl,
                  obscureText: _obscure,
                  style: GoogleFonts.outfit(color: NudgeTokens.textHigh),
                  onChanged: (v) { widget.onKeyChanged(v); },
                  decoration: _inputDec('Gemini API Key', hint: 'AIza...', suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.validated)
                        const Padding(padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.check_circle_rounded, color: NudgeTokens.green, size: 20)),
                      IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: NudgeTokens.textLow, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ],
                  )),
                ),
                const SizedBox(height: 10),
                if (_validationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_validationError!, style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.red)),
                  ),
                FilledButton(
                  onPressed: _validating ? null : _validate,
                  style: FilledButton.styleFrom(
                    backgroundColor: NudgeTokens.purple.withValues(alpha: 0.15),
                    side: const BorderSide(color: NudgeTokens.purple),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _validating
                      ? const SizedBox.square(dimension: 18,
                          child: CircularProgressIndicator(color: NudgeTokens.purple, strokeWidth: 2))
                      : Text(widget.validated ? 'Key Validated ✓' : 'Validate Key',
                          style: GoogleFonts.outfit(fontSize: 14, color: NudgeTokens.purple, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: NudgeTokens.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.info_outline_rounded, color: NudgeTokens.textLow, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Without a key, AI features won\'t work. You can skip and add one later.',
                            style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.settings_outlined, color: NudgeTokens.textLow, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text('You can add multiple API keys in Settings → AI for key rotation & fallback.',
                            style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid))),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        // Fixed bottom actions
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: NudgeTokens.textMid, size: 20),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.validated
                          ? () {
                              final key = _ctrl.text.trim();
                              if (key.isNotEmpty) widget.onKeyChanged(key);
                              widget.onNext();
                            }
                          : () => setState(() => _validationError = 'Please validate your key first, or tap "Skip for now".'),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.validated ? NudgeTokens.purple : NudgeTokens.surface,
                        side: widget.validated ? null : const BorderSide(color: NudgeTokens.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Save & Continue',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600,
                              color: widget.validated ? Colors.white : NudgeTokens.textLow)),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: widget.onSkip,
                child: Text('Skip for now',
                    style: GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.textLow, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — About You
// ─────────────────────────────────────────────────────────────────────────────

class _Step3AboutYou extends StatefulWidget {
  final String name;
  final int age;
  final String gender;
  final double heightCm;
  final String weightKgText;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<int> onAgeChanged;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<String> onWeightChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _Step3AboutYou({
    required this.name,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKgText,
    required this.onNameChanged,
    required this.onAgeChanged,
    required this.onGenderChanged,
    required this.onHeightChanged,
    required this.onWeightChanged,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  State<_Step3AboutYou> createState() => _Step3AboutYouState();
}

class _Step3AboutYouState extends State<_Step3AboutYou> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _ageCtrl = TextEditingController(
        text: widget.age > 0 ? widget.age.toString() : '');
    _weightCtrl = TextEditingController(text: widget.weightKgText);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genders = ['Male', 'Female', 'Other'];
    return Column(
      children: [
        _stepHeader('About You', 'Help us personalise your experience'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NudgeTokens.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: NudgeTokens.amber, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This data stays on your device. Gym, Food & Nutrition modules need your profile to work. You can fill this in later from Settings.',
                          style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.amber),
                        ),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: _nameCtrl,
                  style: GoogleFonts.outfit(color: NudgeTokens.textHigh),
                  onChanged: widget.onNameChanged,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDec('Name', hint: 'Your first name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _ageCtrl,
                  style: GoogleFonts.outfit(color: NudgeTokens.textHigh),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null) widget.onAgeChanged(n);
                  },
                  decoration: _inputDec('Age', hint: '25'),
                ),
                const SizedBox(height: 18),
                Text('Gender', style: _labelStyle()),
                const SizedBox(height: 8),
                Row(
                  children: genders.map((g) {
                    final selected = widget.gender == g;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _ChipButton(
                        label: g,
                        selected: selected,
                        onTap: () => widget.onGenderChanged(g),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Height', style: _labelStyle()),
                    Text(
                      '${widget.heightCm.round()} cm',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: NudgeTokens.purple,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Slider(
                  value: widget.heightCm,
                  min: 140,
                  max: 220,
                  divisions: 80,
                  activeColor: NudgeTokens.purple,
                  inactiveColor: NudgeTokens.border,
                  onChanged: widget.onHeightChanged,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _weightCtrl,
                  style: GoogleFonts.outfit(color: NudgeTokens.textHigh),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: widget.onWeightChanged,
                  decoration: _inputDec('Weight (kg)', hint: '70'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _bottomActions(
          nextLabel: 'Next',
          onNext: widget.onNext,
          onBack: widget.onBack,
          skipLabel: 'Skip (fitness features will be disabled)',
          onSkip: widget.onSkip,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 — Goals
// ─────────────────────────────────────────────────────────────────────────────

class _Step4Goals extends StatefulWidget {
  final Set<String> selectedGoals;
  final String description;
  final ValueChanged<String> onToggleGoal;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step4Goals({
    required this.selectedGoals,
    required this.description,
    required this.onToggleGoal,
    required this.onDescriptionChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step4Goals> createState() => _Step4GoalsState();
}

class _Step4GoalsState extends State<_Step4Goals> {
  late final TextEditingController _descCtrl;

  static const _goals = [
    ('Build Muscle', '💪', NudgeTokens.purple),
    ('Lose Weight', '🔥', NudgeTokens.amber),
    ('Improve Endurance', '🏃', Color(0xFF00BCD4)),
    ('Reduce Stress', '🧘', NudgeTokens.blue),
    ('Save Money', '💰', NudgeTokens.green),
    ('Read More', '📚', Color(0xFFFF9500)),
    ('Build Habits', '🎯', NudgeTokens.red),
  ];

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.description);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _stepHeader('What\'s your mission?', 'Choose all that apply'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _goals.map((g) {
                    final (label, emoji, color) = g;
                    final selected = widget.selectedGoals.contains(label);
                    return GestureDetector(
                      onTap: () => widget.onToggleGoal(label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.12)
                              : NudgeTokens.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? color
                                : NudgeTokens.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selected
                                      ? NudgeTokens.textHigh
                                      : NudgeTokens.textMid,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _descCtrl,
                  style: GoogleFonts.outfit(
                      color: NudgeTokens.textHigh, fontSize: 14),
                  onChanged: widget.onDescriptionChanged,
                  maxLines: 3,
                  decoration: _inputDec(
                    'Describe your ideal outcome',
                    hint: 'e.g. I want to run a 5k in under 30 minutes…',
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _bottomActions(
          nextLabel: 'Next',
          onNext: widget.onNext,
          onBack: widget.onBack,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5 — Activity Level
// ─────────────────────────────────────────────────────────────────────────────

class _Step5Activity extends StatefulWidget {
  final String activityLevel;
  final Set<String> activityTypes;
  final String currentRoutine;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onToggleType;
  final ValueChanged<String> onRoutineChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step5Activity({
    required this.activityLevel,
    required this.activityTypes,
    required this.currentRoutine,
    required this.onLevelChanged,
    required this.onToggleType,
    required this.onRoutineChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step5Activity> createState() => _Step5ActivityState();
}

class _Step5ActivityState extends State<_Step5Activity> {
  late final TextEditingController _routineCtrl;

  static const _levels = ['Beginner', 'Intermediate', 'Advanced'];
  static const _types = [
    'Gym',
    'Running',
    'Cycling',
    'Swimming',
    'Sports',
    'Home Workout',
    'Yoga',
  ];

  @override
  void initState() {
    super.initState();
    _routineCtrl = TextEditingController(text: widget.currentRoutine);
  }

  @override
  void dispose() {
    _routineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _stepHeader('Your Starting Point', 'Tell us about your fitness level'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Experience level', style: _labelStyle()),
                const SizedBox(height: 10),
                Row(
                  children: _levels.map((l) {
                    final selected = widget.activityLevel == l;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _ChipButton(
                          label: l,
                          selected: selected,
                          onTap: () => widget.onLevelChanged(l)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text('Activity types', style: _labelStyle()),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _types.map((t) {
                    final sel = widget.activityTypes.contains(t);
                    return _ChipButton(
                        label: t,
                        selected: sel,
                        onTap: () => widget.onToggleType(t));
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _routineCtrl,
                  style: GoogleFonts.outfit(
                      color: NudgeTokens.textHigh, fontSize: 14),
                  onChanged: widget.onRoutineChanged,
                  maxLines: 3,
                  decoration: _inputDec(
                    'Current routine (optional)',
                    hint: 'e.g. I go to the gym 3x a week…',
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _bottomActions(
          nextLabel: 'Next',
          onNext: widget.onNext,
          onBack: widget.onBack,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 6 — Schedule
// ─────────────────────────────────────────────────────────────────────────────

class _Step6Schedule extends StatefulWidget {
  final Set<int> workoutDays;
  final double sessionMinutes;
  final String scheduleNotes;
  final ValueChanged<int> onToggleDay;
  final ValueChanged<double> onSessionMinutesChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step6Schedule({
    required this.workoutDays,
    required this.sessionMinutes,
    required this.scheduleNotes,
    required this.onToggleDay,
    required this.onSessionMinutesChanged,
    required this.onNotesChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step6Schedule> createState() => _Step6ScheduleState();
}

class _Step6ScheduleState extends State<_Step6Schedule> {
  late final TextEditingController _notesCtrl;
  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.scheduleNotes);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan Your Week', style: _titleStyle()),
                const SizedBox(height: 4),
                Text('When do you want to train?', style: _subtitleStyle()),
                const SizedBox(height: 20),
                Text('Workout days', style: _labelStyle()),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final active = widget.workoutDays.contains(i);
                    return GestureDetector(
                      onTap: () => widget.onToggleDay(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? NudgeTokens.purple
                              : NudgeTokens.card,
                          border: Border.all(
                            color: active
                                ? NudgeTokens.purple
                                : NudgeTokens.border,
                          ),
                        ),
                        child: Text(
                          _dayLabels[i],
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: active
                                ? Colors.white
                                : NudgeTokens.textMid,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rest days: ${_restDayLabel(widget.workoutDays)}',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: NudgeTokens.textLow),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Session length', style: _labelStyle()),
                    Text(
                      '${widget.sessionMinutes.round()} min',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: NudgeTokens.purple,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Slider(
                  value: widget.sessionMinutes,
                  min: 20,
                  max: 120,
                  divisions: 20,
                  activeColor: NudgeTokens.purple,
                  inactiveColor: NudgeTokens.border,
                  onChanged: widget.onSessionMinutesChanged,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  style: GoogleFonts.outfit(
                      color: NudgeTokens.textHigh, fontSize: 14),
                  onChanged: widget.onNotesChanged,
                  maxLines: 3,
                  decoration: _inputDec(
                    'Training preferences (optional)',
                    hint: 'e.g. morning gym 3x a week, evening runs on weekends',
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _bottomActions(
          nextLabel: 'Next',
          onNext: widget.onNext,
          onBack: widget.onBack,
        ),
      ],
    );
  }

  String _restDayLabel(Set<int> workout) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final rest = List.generate(7, (i) => i)
        .where((i) => !workout.contains(i))
        .map((i) => labels[i])
        .toList();
    return rest.isEmpty ? 'None' : rest.join(', ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 7 — Workout Import
// ─────────────────────────────────────────────────────────────────────────────

class _Step7WorkoutImport extends StatefulWidget {
  final List<XFile> images;
  final String workoutDescription;
  final bool hasKey;
  final ValueChanged<List<XFile>> onImagesAdded;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<String> onWorkoutExtracted;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const _Step7WorkoutImport({
    required this.images,
    required this.workoutDescription,
    required this.hasKey,
    required this.onImagesAdded,
    required this.onDescriptionChanged,
    required this.onWorkoutExtracted,
    required this.onNext,
    required this.onSkip,
    required this.onBack,
  });

  @override
  State<_Step7WorkoutImport> createState() => _Step7WorkoutImportState();
}

class _Step7WorkoutImportState extends State<_Step7WorkoutImport> {
  late final TextEditingController _linksCtrl;
  bool _pickingImages = false;
  bool _analysing = false;
  String? _analysisResult;
  String? _analysisError;

  @override
  void initState() {
    super.initState();
    _linksCtrl = TextEditingController(text: widget.workoutDescription);
  }

  @override
  void dispose() {
    _linksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    setState(() => _pickingImages = true);
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isNotEmpty) widget.onImagesAdded(images);
    } catch (_) {
      // Permission denied or unavailable — silently skip
    } finally {
      if (mounted) setState(() => _pickingImages = false);
    }
  }

  Future<void> _analyseWithAI() async {
    if (_analysing) return;
    setState(() {
      _analysing = true;
      _analysisError = null;
      _analysisResult = null;
    });

    try {
      // Build image parts
      final List<({String mimeType, Uint8List bytes})> imgParts = [];
      for (final img in widget.images) {
        final bytes = await img.readAsBytes();
        final mime = img.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        imgParts.add((mimeType: mime, bytes: bytes));
      }

      final description = _linksCtrl.text.trim();
      final prompt = '''
Analyse the provided workout screenshots and/or text description below.
Extract all workout information you can find, including:
- Exercise names
- Sets and reps (or duration)
- Muscle groups targeted
- Any weights or intensity notes
- Overall workout structure/split

User's workout description:
${description.isEmpty ? '(none provided)' : description}

Return a clean, concise summary formatted as a bullet list. If no useful workout data is found, say "No workout data detected".
''';

      final result = await GeminiService.generate(
        prompt: prompt,
        images: imgParts.isEmpty ? null : imgParts,
      );

      if (mounted) {
        if (result != null && result.isNotEmpty) {
          setState(() {
            _analysisResult = result;
            _analysing = false;
          });
          widget.onWorkoutExtracted(result);
        } else {
          setState(() {
            _analysisError = 'No data extracted. Try different images or links.';
            _analysing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisError = e.toString();
          _analysing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = widget.images.isNotEmpty || _linksCtrl.text.trim().isNotEmpty;


    return Column(
      children: [
        _stepHeader('Import Your Workouts', 'Let AI read your existing routines'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image picker area
                GestureDetector(
                  onTap: _pickingImages ? null : _pickImages,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: NudgeTokens.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.images.isNotEmpty
                          ? NudgeTokens.purple.withValues(alpha: 0.5)
                          : NudgeTokens.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          widget.images.isEmpty
                              ? Icons.add_photo_alternate_outlined
                              : Icons.photo_library_rounded,
                          color: widget.images.isEmpty
                              ? NudgeTokens.purple
                              : NudgeTokens.green,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.images.isEmpty
                              ? 'Pick Screenshots'
                              : '${widget.images.length} image${widget.images.length > 1 ? 's' : ''} selected',
                          style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: widget.images.isEmpty
                                  ? NudgeTokens.textHigh
                                  : NudgeTokens.green,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'workout plans, spreadsheets, notes',
                          style: _labelStyle(),
                        ),
                      ],
                    ),
                  ),
                ),
                // Thumbnails
                if (widget.images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(widget.images[i].path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _linksCtrl,
                  style: GoogleFonts.outfit(
                      color: NudgeTokens.textHigh, fontSize: 13),
                  onChanged: widget.onDescriptionChanged,
                  maxLines: 4,
                  decoration: _inputDec(
                    'Describe your current workout (optional)',
                    hint: 'e.g. 3x push pull legs, 5x5 Stronglifts, PPL split…',
                  ),
                ),
                const SizedBox(height: 14),
                // AI Required notice if no key
                if (!widget.hasKey)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NudgeTokens.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: NudgeTokens.amber, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'AI is required to analyse workouts. Add a Gemini key in the previous step or Settings.',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: NudgeTokens.amber),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (hasContent) ...[
                  // Analyse button
                  FilledButton.icon(
                    onPressed: _analysing ? null : _analyseWithAI,
                    icon: _analysing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded,
                            size: 16, color: Colors.white),
                    label: Text(
                      _analysing
                          ? 'Analysing…'
                          : (_analysisResult != null ? 'Re-analyse' : 'Analyse with AI'),
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: Colors.white),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: NudgeTokens.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NudgeTokens.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NudgeTokens.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome_outlined,
                            color: NudgeTokens.amber, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add screenshots or describe your current split above, then tap Analyse to extract exercises automatically.',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: NudgeTokens.textMid),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Analysis error
                if (_analysisError != null) ...[
                  const SizedBox(height: 10),
                  Text(_analysisError!,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: NudgeTokens.red)),
                ],
                // Analysis result
                if (_analysisResult != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NudgeTokens.green.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: NudgeTokens.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: NudgeTokens.green, size: 16),
                            const SizedBox(width: 8),
                            Text('Extracted workout data',
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: NudgeTokens.green,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _analysisResult!,
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: NudgeTokens.textMid,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _bottomActions(
          nextLabel: 'Continue',
          onNext: widget.onNext,
          skipLabel: 'Skip this step',
          onSkip: widget.onSkip,
          onBack: widget.onBack,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 8 — Calorie & Hydration
// ─────────────────────────────────────────────────────────────────────────────

class _Step8CalorieHydration extends StatefulWidget {
  final bool dynamicTargets;
  final double calorieGoal;
  final double waterGoalMl;
  final double calorieAdjPer100;
  final int tdeeCalc;
  final int recommendedWater;
  final String? fitnessPlan;
  final bool hasKey;
  final ValueChanged<bool> onDynamicChanged;
  final ValueChanged<double> onCalorieChanged;
  final ValueChanged<double> onWaterChanged;
  final ValueChanged<double> onAdjChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step8CalorieHydration({
    required this.dynamicTargets,
    required this.calorieGoal,
    required this.waterGoalMl,
    required this.calorieAdjPer100,
    required this.tdeeCalc,
    required this.recommendedWater,
    this.fitnessPlan,
    required this.hasKey,
    required this.onDynamicChanged,
    required this.onCalorieChanged,
    required this.onWaterChanged,
    required this.onAdjChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step8CalorieHydration> createState() => _Step8CalorieHydrationState();
}

class _Step8CalorieHydrationState extends State<_Step8CalorieHydration> {
  bool _aiLoading = false;
  String? _aiSuggestion;

  Future<void> _getAiSuggestion() async {
    if (_aiLoading || widget.fitnessPlan == null) return;
    setState(() { _aiLoading = true; _aiSuggestion = null; });
    try {
      final result = await GeminiService.generate(
        prompt: '''Based on this fitness plan, recommend daily nutrition targets.
Return ONLY a single line in this exact format (no other text):
CALORIES:<number> WATER:<number>

FITNESS PLAN:
${widget.fitnessPlan}''',
      );
      if (result != null && mounted) {
        // Parse "CALORIES:2200 WATER:2800"
        final calMatch = RegExp(r'CALORIES:(\d+)').firstMatch(result);
        final waterMatch = RegExp(r'WATER:(\d+)').firstMatch(result);
        final cals = double.tryParse(calMatch?.group(1) ?? '');
        final water = double.tryParse(waterMatch?.group(1) ?? '');
        if (cals != null) widget.onCalorieChanged(cals.clamp(1200.0, 4000.0));
        if (water != null) widget.onWaterChanged(water.clamp(1000.0, 5000.0));
        setState(() => _aiSuggestion = 'Applied: ${cals?.round() ?? '?'} kcal · ${water?.round() ?? '?'} ml');
      }
    } catch (_) {
      setState(() => _aiSuggestion = 'Could not get suggestion — using TDEE estimate.');
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fuel Your Goals', style: _titleStyle()),
                const SizedBox(height: 4),
                Text('Set your daily nutrition targets', style: _subtitleStyle()),
                const SizedBox(height: 20),

                // AI suggestion row (if fitness plan available)
                if (widget.fitnessPlan != null && widget.hasKey)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: _aiLoading ? null : _getAiSuggestion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: NudgeTokens.gymB.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: NudgeTokens.gymB.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            _aiLoading
                                ? const SizedBox.square(dimension: 16,
                                    child: CircularProgressIndicator(color: NudgeTokens.gymB, strokeWidth: 2))
                                : const Icon(Icons.auto_awesome_rounded, color: NudgeTokens.gymB, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _aiSuggestion ?? 'Apply AI nutrition targets from your fitness plan',
                                style: GoogleFonts.outfit(fontSize: 12,
                                    color: _aiSuggestion != null ? NudgeTokens.green : NudgeTokens.gymB),
                              ),
                            ),
                            if (_aiSuggestion == null)
                              Text('Apply', style: GoogleFonts.outfit(fontSize: 12,
                                  color: NudgeTokens.gymB, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // TDEE estimate row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: NudgeTokens.purple.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calculate_outlined, color: NudgeTokens.purple, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'TDEE estimate: ~${widget.tdeeCalc} kcal · ${widget.recommendedWater} ml',
                          style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          widget.onCalorieChanged(widget.tdeeCalc.toDouble().clamp(1200.0, 4000.0));
                          widget.onWaterChanged(widget.recommendedWater.toDouble().clamp(1000.0, 5000.0));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: NudgeTokens.purple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Use', style: GoogleFonts.outfit(
                              fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Dynamic toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: NudgeTokens.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: widget.dynamicTargets ? NudgeTokens.purple : NudgeTokens.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dynamic targets',
                                style: GoogleFonts.outfit(fontSize: 14,
                                    color: NudgeTokens.textHigh, fontWeight: FontWeight.w600)),
                            Text('Adjusts daily based on activity', style: _labelStyle()),
                          ],
                        ),
                      ),
                      Switch(
                        value: widget.dynamicTargets,
                        activeThumbColor: NudgeTokens.purple,
                        onChanged: widget.onDynamicChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SliderField(
                  label: widget.dynamicTargets ? 'Base calorie goal' : 'Calorie target',
                  value: widget.calorieGoal,
                  unit: 'kcal',
                  min: 1200,
                  max: 4000,
                  divisions: 56,
                  onChanged: widget.onCalorieChanged,
                  color: NudgeTokens.amber,
                ),
                const SizedBox(height: 16),
                _SliderField(
                  label: 'Daily water goal',
                  value: widget.waterGoalMl,
                  unit: 'ml',
                  min: 1000,
                  max: 5000,
                  divisions: 40,
                  onChanged: widget.onWaterChanged,
                  color: NudgeTokens.blue,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _bottomActions(
          nextLabel: 'Next',
          onNext: widget.onNext,
          onBack: widget.onBack,
        ),
      ],
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final Color color;

  const _SliderField({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: NudgeTokens.textMid)),
            Text(
              '${value.round()} $unit',
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: color,
          inactiveColor: NudgeTokens.border,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 9 — Finance
// ─────────────────────────────────────────────────────────────────────────────

class _Step9Finance extends StatefulWidget {
  final String monthlyIncome;
  final String monthlyBudget;
  final double savingsPct;
  final String currency;
  final ValueChanged<String> onIncomeChanged;
  final ValueChanged<String> onBudgetChanged;
  final ValueChanged<double> onSavingsChanged;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step9Finance({
    required this.monthlyIncome,
    required this.monthlyBudget,
    required this.savingsPct,
    required this.currency,
    required this.onIncomeChanged,
    required this.onBudgetChanged,
    required this.onSavingsChanged,
    required this.onCurrencyChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step9Finance> createState() => _Step9FinanceState();
}

class _Step9FinanceState extends State<_Step9Finance> {
  late final TextEditingController _incomeCtrl;
  late final TextEditingController _budgetCtrl;
  static const _currencies = ['£', '\$', '₹', '€'];

  @override
  void initState() {
    super.initState();
    _incomeCtrl = TextEditingController(text: widget.monthlyIncome);
    _budgetCtrl = TextEditingController(text: widget.monthlyBudget);
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Money Mindfulness', style: _titleStyle()),
                const SizedBox(height: 4),
                Text('Set your financial boundaries', style: _subtitleStyle()),
                const SizedBox(height: 20),
                Text('Currency', style: _labelStyle()),
                const SizedBox(height: 8),
                Row(
                  children: _currencies.map((c) {
                    final sel = widget.currency == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _ChipButton(
                          label: c, selected: sel,
                          onTap: () => widget.onCurrencyChanged(c)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _incomeCtrl,
                  style: GoogleFonts.outfit(color: NudgeTokens.textHigh),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: widget.onIncomeChanged,
                  decoration: _inputDec(
                    'Monthly income (optional)',
                    hint: '3000',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _budgetCtrl,
                  style: GoogleFonts.outfit(color: NudgeTokens.textHigh),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: widget.onBudgetChanged,
                  decoration: _inputDec(
                    'Monthly spending limit',
                    hint: '1500',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Savings goal', style: _labelStyle()),
                    Text(
                      '${widget.savingsPct.round()}%',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: NudgeTokens.green,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Slider(
                  value: widget.savingsPct,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  activeColor: NudgeTokens.green,
                  inactiveColor: NudgeTokens.border,
                  onChanged: widget.onSavingsChanged,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _bottomActions(
          nextLabel: 'Next',
          onNext: widget.onNext,
          onBack: widget.onBack,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 10 — Modules
// ─────────────────────────────────────────────────────────────────────────────

class _Step10Modules extends StatelessWidget {
  final Map<String, bool> modules;
  final void Function(String key, bool value) onToggle;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step10Modules({
    required this.modules,
    required this.onToggle,
    required this.onNext,
    required this.onBack,
  });

  static const _icons = {
    'Gym & Fitness': Icons.fitness_center_rounded,
    'Food & Nutrition': Icons.restaurant_menu_rounded,
    'Finance': Icons.credit_card_rounded,
    'Movies': Icons.movie_outlined,
    'Books': Icons.menu_book_rounded,
    'Pomodoro': Icons.timer_outlined,
    'Protected Habits': Icons.shield_outlined,
    'Digital Detox': Icons.phone_locked_outlined,
  };

  static const _descriptions = {
    'Gym & Fitness': 'Workouts, exercises & progress tracking',
    'Food & Nutrition': 'Calorie counting & meal logging',
    'Finance': 'Expenses, budget & spending insights',
    'Movies': 'Watch list & movie ratings',
    'Books': 'Reading list & progress',
    'Pomodoro': 'Focus timer & productivity sessions',
    'Protected Habits': 'PIN-locked private habit tracker',
    'Digital Detox': 'Screen time & app usage limits',
  };

  static const _colors = {
    'Gym & Fitness': NudgeTokens.gymB,
    'Food & Nutrition': NudgeTokens.foodB,
    'Finance': NudgeTokens.finB,
    'Movies': NudgeTokens.moviesB,
    'Books': NudgeTokens.booksB,
    'Pomodoro': NudgeTokens.pomB,
    'Protected Habits': NudgeTokens.protB,
    'Digital Detox': NudgeTokens.amber,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _stepHeader('Choose Your Features', 'Toggle off what you don\'t need'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: modules.entries.map((e) {
              final icon = _icons[e.key] ?? Icons.apps_rounded;
              final desc = _descriptions[e.key] ?? '';
              final color = _colors[e.key] ?? NudgeTokens.purple;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: e.value
                        ? color.withValues(alpha: 0.08)
                        : NudgeTokens.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: e.value ? color.withValues(alpha: 0.5) : NudgeTokens.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key,
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: NudgeTokens.textHigh,
                                    fontWeight: FontWeight.w600)),
                            Text(desc,
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: NudgeTokens.textLow)),
                          ],
                        ),
                      ),
                      Switch(
                        value: e.value,
                        activeThumbColor: color,
                        onChanged: (v) => onToggle(e.key, v),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        _bottomActions(
          nextLabel: 'Next',
          onNext: onNext,
          onBack: onBack,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 11 — AI Plan Generation
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Shared markdown renderer — sections are collapsible cards
// ─────────────────────────────────────────────────────────────────────────────

class _MarkdownText extends StatelessWidget {
  final String text;
  const _MarkdownText({required this.text});

  @override
  Widget build(BuildContext context) {
    // Split by ## headings into sections
    final sectionRegex = RegExp(r'(?=## )');
    final parts = text.split(sectionRegex);

    // First part may be preamble (before first ##)
    final widgets = <Widget>[];
    for (final part in parts) {
      if (part.trim().isEmpty) continue;
      if (part.startsWith('## ')) {
        final newline = part.indexOf('\n');
        final heading = newline == -1 ? part.substring(3).trim() : part.substring(3, newline).trim();
        final body = newline == -1 ? '' : part.substring(newline + 1).trim();
        widgets.add(_SectionCard(heading: heading, body: body));
      } else {
        // Preamble text
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _InlineText(text: part.trim()),
        ));
      }
    }

    // If no ## sections found, just render inline
    if (widgets.isEmpty) {
      return _InlineText(text: text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

class _SectionCard extends StatefulWidget {
  final String heading;
  final String body;
  const _SectionCard({required this.heading, required this.body});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Expand first section by default
    _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: NudgeTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _expanded ? NudgeTokens.purple.withValues(alpha: 0.35) : NudgeTokens.border),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _expanded ? NudgeTokens.purple : NudgeTokens.textLow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.heading,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _expanded ? NudgeTokens.textHigh : NudgeTokens.textMid,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: NudgeTokens.textLow,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && widget.body.isNotEmpty) ...[
              Divider(height: 1, color: NudgeTokens.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: _InlineText(text: widget.body),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineText extends StatelessWidget {
  final String text;
  const _InlineText({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('* ') || line.startsWith('- ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: GoogleFonts.outfit(fontSize: 12.5, color: NudgeTokens.purple)),
                Expanded(child: _richLine(line.substring(2))),
              ],
            ),
          );
        } else if (line.startsWith('### ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(line.substring(4),
                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: NudgeTokens.textHigh)),
          );
        } else if (line.trim().isEmpty) {
          return const SizedBox(height: 4);
        } else {
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _richLine(line),
          );
        }
      }).toList(),
    );
  }

  Widget _richLine(String line) {
    // Parse **bold** inline
    final spans = <TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final m in boldRegex.allMatches(line)) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: line.substring(last, m.start),
          style: GoogleFonts.outfit(fontSize: 12.5, color: NudgeTokens.textMid, height: 1.5),
        ));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: GoogleFonts.outfit(fontSize: 12.5, color: NudgeTokens.textHigh, fontWeight: FontWeight.w600, height: 1.5),
      ));
      last = m.end;
    }
    if (last < line.length) {
      spans.add(TextSpan(
        text: line.substring(last),
        style: GoogleFonts.outfit(fontSize: 12.5, color: NudgeTokens.textMid, height: 1.5),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 11 — Fitness Plan Generation
// ─────────────────────────────────────────────────────────────────────────────

class _Step11FitnessPlan extends StatefulWidget {
  final bool generating;
  final String? plan;
  final String? error;
  final List<String> warnings;
  final bool safetyChecking;
  final String statusMessage;
  final bool hasKey;
  final String notes;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onGenerate;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step11FitnessPlan({
    required this.generating,
    required this.plan,
    required this.error,
    required this.warnings,
    this.safetyChecking = false,
    required this.statusMessage,
    required this.hasKey,
    required this.notes,
    required this.onNotesChanged,
    required this.onGenerate,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step11FitnessPlan> createState() => _Step11FitnessPlanState();
}

class _Step11FitnessPlanState extends State<_Step11FitnessPlan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final TextEditingController _notesCtrl;
  bool _warningsAcknowledged = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _notesCtrl = TextEditingController(text: widget.notes);
    _warningsAcknowledged = widget.warnings.isEmpty;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _stepHeader('Fitness Plan', 'AI-generated workout programme'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Privacy notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NudgeTokens.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NudgeTokens.blue.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.shield_outlined, color: NudgeTokens.blue, size: 15),
                        const SizedBox(width: 8),
                        Text('What goes to Google\'s servers',
                            style: GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.blue, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '• Age, gender, height & weight\n'
                        '• Activity level & workout schedule\n'
                        '• Goals & calorie/water targets\n'
                        '• Imported workout data (if any)\n\n'
                        '✗ Your name is NOT sent.',
                        style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // AI safety check in progress
                if (widget.safetyChecking) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: NudgeTokens.purple.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox.square(dimension: 14,
                            child: CircularProgressIndicator(color: NudgeTokens.purple, strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Text('AI is checking your goals for safety…',
                            style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Warnings
                if (widget.warnings.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NudgeTokens.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: NudgeTokens.amber, size: 16),
                          const SizedBox(width: 8),
                          Text('Health & Safety Flags',
                              style: GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.amber, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 10),
                        ...widget.warnings.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('⚠ ', style: TextStyle(color: NudgeTokens.amber, fontSize: 12)),
                              Expanded(child: Text(w, style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid, height: 1.4))),
                            ],
                          ),
                        )),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() => _warningsAcknowledged = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _warningsAcknowledged
                                  ? NudgeTokens.green.withValues(alpha: 0.12)
                                  : NudgeTokens.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _warningsAcknowledged ? NudgeTokens.green : NudgeTokens.amber),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _warningsAcknowledged ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                                  color: _warningsAcknowledged ? NudgeTokens.green : NudgeTokens.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _warningsAcknowledged ? 'Acknowledged' : 'I understand, proceed anyway',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: _warningsAcknowledged ? NudgeTokens.green : NudgeTokens.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Generate button / loading / error / plan
                if (widget.generating) ...[
                  const SizedBox(height: 16),
                  const Center(child: OrbitAnimation(size: 140)),
                  const SizedBox(height: 20),
                  Center(
                    child: FadeTransition(
                      opacity: _pulseCtrl,
                      child: Text(widget.statusMessage, textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 14, color: NudgeTokens.textMid)),
                    ),
                  ),
                ] else if (widget.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NudgeTokens.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NudgeTokens.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: NudgeTokens.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.error!, style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.red))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _generateButton(onTap: widget.onGenerate, label: 'Try Again'),
                ] else if (widget.plan == null) ...[
                  // Pre-generate state
                  if (!widget.hasKey)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NudgeTokens.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.key_off_rounded, color: NudgeTokens.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('No Gemini key — you can skip this step and add one later in Settings.',
                              style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid))),
                        ],
                      ),
                    )
                  else
                    _generateButton(
                      onTap: (!_warningsAcknowledged && widget.warnings.isNotEmpty) ? null : widget.onGenerate,
                      label: 'Generate Fitness Plan',
                      icon: Icons.fitness_center_rounded,
                      disabled: !_warningsAcknowledged && widget.warnings.isNotEmpty,
                    ),
                ] else ...[
                  // Plan display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NudgeTokens.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: NudgeTokens.gymB.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: NudgeTokens.gymB, size: 16),
                            const SizedBox(width: 8),
                            Text('Your Fitness Plan',
                                style: GoogleFonts.outfit(fontSize: 14, color: NudgeTokens.gymB, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            GestureDetector(
                              onTap: widget.onGenerate,
                              child: Text('Regenerate',
                                  style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textLow)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _MarkdownText(text: widget.plan!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Adjustment notes
                  TextField(
                    controller: _notesCtrl,
                    style: GoogleFonts.outfit(color: NudgeTokens.textHigh, fontSize: 13),
                    onChanged: widget.onNotesChanged,
                    maxLines: 3,
                    decoration: _inputDec(
                      'Adjustments or notes',
                      hint: 'e.g. no running, prefer home workouts, add more core...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _generateButton(onTap: widget.onGenerate, label: 'Regenerate with Notes'),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        _bottomActions(
          nextLabel: widget.plan != null || !widget.hasKey ? 'Next' : 'Skip Fitness Plan',
          onNext: widget.onNext,
          onBack: widget.onBack,
        ),
      ],
    );
  }

  Widget _generateButton({required VoidCallback? onTap, required String label, IconData? icon, bool disabled = false}) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon ?? Icons.auto_awesome_rounded, size: 16, color: disabled ? NudgeTokens.textLow : Colors.white),
      label: Text(label, style: GoogleFonts.outfit(fontSize: 14, color: disabled ? NudgeTokens.textLow : Colors.white)),
      style: FilledButton.styleFrom(
        backgroundColor: disabled ? NudgeTokens.surface : NudgeTokens.purple,
        side: disabled ? const BorderSide(color: NudgeTokens.border) : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 12 — Finance Plan
// ─────────────────────────────────────────────────────────────────────────────

class _Step12FinancePlan extends StatefulWidget {
  final bool generating;
  final String? plan;
  final String? error;
  final String statusMessage;
  final bool hasKey;
  final bool aiEnabled;
  final String debtAmount;
  final String investmentGoal;
  final String monthlyIncome;
  final String monthlyBudget;
  final double savingsPct;
  final String currency;
  final ValueChanged<bool> onAiEnabledChanged;
  final ValueChanged<String> onDebtChanged;
  final ValueChanged<String> onInvestmentGoalChanged;
  final VoidCallback onGenerate;
  final Future<void> Function() onDone;
  final VoidCallback onBack;

  const _Step12FinancePlan({
    required this.generating,
    required this.plan,
    required this.error,
    required this.statusMessage,
    required this.hasKey,
    required this.aiEnabled,
    required this.debtAmount,
    required this.investmentGoal,
    required this.monthlyIncome,
    required this.monthlyBudget,
    required this.savingsPct,
    required this.currency,
    required this.onAiEnabledChanged,
    required this.onDebtChanged,
    required this.onInvestmentGoalChanged,
    required this.onGenerate,
    required this.onDone,
    required this.onBack,
  });

  @override
  State<_Step12FinancePlan> createState() => _Step12FinancePlanState();
}

class _Step12FinancePlanState extends State<_Step12FinancePlan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final TextEditingController _debtCtrl;
  late final TextEditingController _investCtrl;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _debtCtrl = TextEditingController(text: widget.debtAmount);
    _investCtrl = TextEditingController(text: widget.investmentGoal);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _debtCtrl.dispose();
    _investCtrl.dispose();
    super.dispose();
  }

  // 50/30/20 quick calculation
  Widget _buildFrameworkCard() {
    final income = double.tryParse(widget.monthlyIncome) ?? 0.0;
    if (income <= 0) return const SizedBox.shrink();
    final needs = income * 0.50;
    final wants = income * 0.30;
    final savings = income * 0.20;
    final cur = widget.currency;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NudgeTokens.finA,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NudgeTokens.finB.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calculate_outlined, color: NudgeTokens.finB, size: 15),
            const SizedBox(width: 8),
            Text('50/30/20 Rule (based on your income)',
                style: GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.finB, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          _frameworkRow('Needs (50%)', '$cur${needs.toStringAsFixed(0)}', 'Rent, bills, groceries'),
          _frameworkRow('Wants (30%)', '$cur${wants.toStringAsFixed(0)}', 'Entertainment, dining out'),
          _frameworkRow('Savings (20%)', '$cur${savings.toStringAsFixed(0)}', 'Emergency fund, investments'),
          const SizedBox(height: 6),
          Text('Source: Elizabeth Warren\'s "All Your Worth" (2005)',
              style: GoogleFonts.outfit(fontSize: 10, color: NudgeTokens.textLow, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _frameworkRow(String label, String value, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(
              color: NudgeTokens.finB,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textHigh, fontWeight: FontWeight.w600)),
                    Text(value, style: GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.finB, fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(desc, style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _stepHeader('Finance Plan', 'Build your financial foundation'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Additional inputs
                TextField(
                  controller: _debtCtrl,
                  style: GoogleFonts.outfit(color: NudgeTokens.textHigh),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: widget.onDebtChanged,
                  decoration: _inputDec('Monthly debt repayments (optional)', hint: '250'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _investCtrl,
                  style: GoogleFonts.outfit(color: NudgeTokens.textHigh, fontSize: 13),
                  onChanged: widget.onInvestmentGoalChanged,
                  decoration: _inputDec('Investment goal (optional)', hint: 'e.g. retirement, buy house, index funds'),
                ),
                const SizedBox(height: 16),

                // 50/30/20 framework
                _buildFrameworkCard(),
                const SizedBox(height: 14),

                // AI toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: NudgeTokens.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: NudgeTokens.purple, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI Financial Analysis', style: GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.textHigh, fontWeight: FontWeight.w600)),
                            Text('Generate personalised advice using Gemini', style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow)),
                          ],
                        ),
                      ),
                      Switch(
                        value: widget.aiEnabled,
                        activeThumbColor: NudgeTokens.purple,
                        onChanged: widget.onAiEnabledChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Privacy notice (only if AI enabled)
                if (widget.aiEnabled) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NudgeTokens.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NudgeTokens.blue.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.shield_outlined, color: NudgeTokens.blue, size: 15),
                          const SizedBox(width: 8),
                          Text('What goes to Google\'s servers',
                              style: GoogleFonts.outfit(fontSize: 13, color: NudgeTokens.blue, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          '• Monthly income & budget\n'
                          '• Savings % & debt amount\n'
                          '• Investment goals (if entered)\n\n'
                          '✗ Your name is NOT sent.',
                          style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Generating / error / plan
                if (widget.generating) ...[
                  const SizedBox(height: 10),
                  const Center(child: OrbitAnimation(size: 120)),
                  const SizedBox(height: 16),
                  Center(
                    child: FadeTransition(
                      opacity: _pulseCtrl,
                      child: Text(widget.statusMessage, textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 14, color: NudgeTokens.textMid)),
                    ),
                  ),
                ] else if (widget.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NudgeTokens.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NudgeTokens.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: NudgeTokens.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.error!, style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.red))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.aiEnabled)
                    FilledButton.icon(
                      onPressed: widget.onGenerate,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text('Try Again', style: GoogleFonts.outfit(fontSize: 14)),
                      style: FilledButton.styleFrom(backgroundColor: NudgeTokens.finB,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    ),
                ] else if (widget.plan == null && widget.aiEnabled) ...[
                  if (!widget.hasKey)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NudgeTokens.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NudgeTokens.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.key_off_rounded, color: NudgeTokens.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('No Gemini key — framework recommendations above still apply.',
                              style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textMid))),
                        ],
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: widget.onGenerate,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                      label: Text('Generate Finance Plan', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
                      style: FilledButton.styleFrom(
                        backgroundColor: NudgeTokens.finB,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                ] else if (widget.plan != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: NudgeTokens.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: NudgeTokens.finB.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: NudgeTokens.finB, size: 16),
                            const SizedBox(width: 8),
                            Text('Your Finance Plan', style: GoogleFonts.outfit(fontSize: 14, color: NudgeTokens.finB, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (widget.aiEnabled)
                              GestureDetector(
                                onTap: widget.onGenerate,
                                child: Text('Regenerate', style: GoogleFonts.outfit(fontSize: 12, color: NudgeTokens.textLow)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _MarkdownText(text: widget.plan!),
                      ],
                    ),
                  ),
                ],

                // Disclaimer
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NudgeTokens.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: NudgeTokens.border),
                  ),
                  child: Text(
                    '⚠ Disclaimer: All financial information provided is for educational purposes only and does not constitute regulated financial advice. Past performance is not indicative of future results. Consult a qualified financial adviser before making investment decisions.',
                    style: GoogleFonts.outfit(fontSize: 11, color: NudgeTokens.textLow, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        // Bottom actions
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: NudgeTokens.textMid, size: 20),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: (widget.generating || _completing)
                      ? null
                      : () async {
                          setState(() => _completing = true);
                          await widget.onDone();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: NudgeTokens.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _completing
                      ? const SizedBox.square(dimension: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Go to Nudge', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared chip button
// ─────────────────────────────────────────────────────────────────────────────

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const c = NudgeTokens.purple;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : NudgeTokens.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? c : NudgeTokens.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? NudgeTokens.textHigh : NudgeTokens.textMid,
          ),
        ),
      ),
    );
  }
}
