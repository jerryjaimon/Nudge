// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../app.dart' show NudgeTokens;
import '../storage.dart';
import 'home_screen.dart';
import 'package:nudge/utils/gemini_service.dart';
import '../utils/mock_data_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/sign_in_screen.dart';
import 'onboarding/restore_from_cloud_screen.dart';

// ─── Onboarding steps ────────────────────────────────────────────────────────
//  0  Welcome
//  1  Module selection
//  2  Fitness goals (multi-select + free text)
//  3  Current level + routine description
//  4  Gym commitment (days/week)
//  5  Water goal
//  6  Budget goal
//  7  AI Progression (auto-generates & advances)
//  8  Summary

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 11;

  // ── Module selection ──────────────────────────────────────────────────────
  final Set<String> _selectedModules = {
    'gym', 'food', 'finance', 'movies', 'books', 'detox'
  };

  final Set<String> _fitnessGoals = {};
  final _goalDescCtrl = TextEditingController();

  // ── Activity Types ────────────────────────────────────────────────────────
  final Set<String> _activityTypes = {};
  final _activityDescCtrl = TextEditingController();

  // ── Current level ─────────────────────────────────────────────────────────
  String _fitnessLevel = 'Beginner';
  final _routineDescCtrl = TextEditingController();

  // ── Commitments ───────────────────────────────────────────────────────────
  int _gymDays = 3;
  int _waterGoal = 2000;
  double _budgetGoal = 1000.0;

  // ── AI Agent Setup ────────────────────────────────────────────────────────
  final _geminiKeyCtrl = TextEditingController();

  // ── AI Progression ────────────────────────────────────────────────────────
  bool _generatingPlan = false;
  String? _aiPlan;
  String _aiStatusText = 'Analysing your profile…';

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    _goalDescCtrl.dispose();
    _routineDescCtrl.dispose();
    _geminiKeyCtrl.dispose();
    super.dispose();
  }

  void _animateIn() {
    _fadeCtrl.reset();
    _slideCtrl.reset();
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  Future<void> _next() async {
    // Step 9 = AI generation — handle separately
    if (_currentStep == 9) {
      if (_aiPlan != null) {
        _goToStep(10);
      }
      return;
    }

    // Step 8 = AI Agent Setup: Validate API Key and move to generation
    if (_currentStep == 8) {
      final key = _geminiKeyCtrl.text.trim();
      if (key.isNotEmpty) {
        AppStorage.settingsBox.put('gemini_api_key_1', key);
        AppStorage.settingsBox.put('active_gemini_key_index', 1);
      }
      _goToStep(9);
      _generateProgression();
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    } else {
      _finish();
    }
    HapticFeedback.mediumImpact();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _animateIn();
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_currentStep > 0 && _currentStep != 9) {
      _goToStep(_currentStep - 1);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _generateProgression() async {
    if (_generatingPlan) return;
    setState(() {
      _generatingPlan = true;
      _aiPlan = null;
      _aiStatusText = 'Analysing your profile…';
    });

    // Cycle status messages for UX feel
    final statuses = [
      'Analysing your profile…',
      'Mapping your fitness goals…',
      'Calculating progressive overload…',
      'Building your week plan…',
      'Finalising rep ranges & load…',
      'Almost ready…',
    ];
    int msgIdx = 0;
    final msgTimer = Stream.periodic(const Duration(milliseconds: 1800), (_) {
      msgIdx = (msgIdx + 1) % statuses.length;
      return statuses[msgIdx];
    });
    final sub = msgTimer.listen((msg) {
      if (mounted) setState(() => _aiStatusText = msg);
    });

    final goalList = _fitnessGoals.isEmpty
        ? 'General fitness'
        : _fitnessGoals.join(', ');
    final goalDesc = _goalDescCtrl.text.trim();
    final activityList = _activityTypes.isEmpty
        ? 'General Training'
        : _activityTypes.join(', ');
    final activityDesc = _activityDescCtrl.text.trim();
    final routineDesc = _routineDescCtrl.text.trim();

    final prompt = '''
You are an expert personal trainer and periodisation coach.
Create a personalised 8-week progressive workout plan for this user.

USER PROFILE:
- Primary goals: $goalList
${goalDesc.isNotEmpty ? '- Goal description: "$goalDesc"' : ''}
- Training style/Activity types: $activityList
${activityDesc.isNotEmpty ? '- Activity details: "$activityDesc"' : ''}
- Current level: $_fitnessLevel
${routineDesc.isNotEmpty ? '- Current routine: "$routineDesc"' : ''}
- Training days per week: $_gymDays
- Water intake goal: ${_waterGoal}ml/day

OUTPUT FORMAT (markdown, keep it tight and actionable):

## Your 8-Week Plan

One bold opening sentence summarising the plan philosophy.

## Phase 1: Weeks 1–4 — Foundation
3–4 bullet points. Focus on form, base strength, and progressive overload specifics.
Include example week structure (e.g. "Day A: Push, Day B: Pull, Day C: Legs").

## Phase 2: Weeks 5–8 — Intensity
3–4 bullet points. How to progress: % increases, rep range shifts, technique cues.

## Weekly Targets
- Sets/session: X–Y working sets
- Rep ranges: [primary goal-appropriate ranges]
- Rest periods: [goal-appropriate]
- Progression rule: [specific e.g. "+2.5 kg when all reps hit top of range"]

## Recovery & Nutrition Tips
2–3 bullets, data-driven, no fluff.

Keep it under 350 words. No filler sentences.
''';

    try {
      final result = await GeminiService.generate(prompt: prompt);
      sub.cancel();
      if (!mounted) return;
      setState(() {
        _aiPlan = result ?? _fallbackPlan();
        _generatingPlan = false;
      });
    } catch (_) {
      sub.cancel();
      if (!mounted) return;
      setState(() {
        _aiPlan = _fallbackPlan();
        _generatingPlan = false;
      });
    }
  }

  String _fallbackPlan() => '''
## Your 8-Week Plan

A structured progressive plan built around your $_gymDays training days/week.

## Phase 1: Weeks 1–4 — Foundation
- Focus on compound lifts: squat, hinge, push, pull
- 3 working sets × 8–12 reps at 65–70% effort
- Add 2.5 kg when you hit the top rep range across all sets
- Log every session for accountability

## Phase 2: Weeks 5–8 — Intensity
- Increase to 4 working sets; drop rep range to 6–8
- Introduce 1 top-set (90% effort) per primary lift
- Add accessory work (2 × 12–15) for lagging muscles
- Deload in Week 8: drop volume by 40%

## Weekly Targets
- Sets/session: 12–16 working sets
- Rep ranges: 8–12 (hypertrophy) / 4–6 (strength)
- Rest: 2–3 min compound, 60–90 s accessory
- Progression: +2.5 kg when all reps complete

## Recovery & Nutrition Tips
- Protein: 1.6–2.2 g/kg bodyweight daily
- Sleep 7–9 h; most growth happens during recovery
- Keep protein within 30 min post-workout
''';

  void _finish() {
    AppStorage.enabledModules = _selectedModules.toList();
    AppStorage.waterGoal = _waterGoal;
    AppStorage.gymGoalDays = _gymDays;
    AppStorage.financeBudget = _budgetGoal;
    AppStorage.hasSeenOnboarding = true;

    // Save fitness profile to settings
    AppStorage.settingsBox.put('fitness_goals', _fitnessGoals.toList());
    AppStorage.settingsBox.put('fitness_level', _fitnessLevel);
    AppStorage.settingsBox.put('goal_description', _goalDescCtrl.text.trim());
    AppStorage.settingsBox.put('activity_types', _activityTypes.toList());
    AppStorage.settingsBox.put('activity_description', _activityDescCtrl.text.trim());
    AppStorage.settingsBox.put('routine_description', _routineDescCtrl.text.trim());
    if (_aiPlan != null) {
      AppStorage.settingsBox.put('ai_progression_plan', _aiPlan);
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const HomeScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAiStep = _currentStep == 9;
    final canGoBack = _currentStep > 0 && !isAiStep;
    final isLastStep = _currentStep == _totalSteps - 1;

    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: List.generate(_totalSteps, (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: i <= _currentStep
                          ? NudgeTokens.purple
                          : NudgeTokens.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Step ${_currentStep + 1} of $_totalSteps',
                    style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: NudgeTokens.textLow,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: FadeTransition(
                opacity: _fadeCtrl,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: _slideCtrl, curve: Curves.easeOutCubic)),
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildWelcome(),
                      _buildModuleSelection(),
                      _buildFitnessGoals(),
                      _buildActivityTypes(),
                      _buildCurrentLevel(),
                      _buildGymCommitment(),
                      _buildWaterGoal(),
                      _buildBudgetGoal(),
                      _buildAiAgentSetup(),
                      _buildAiProgression(),
                      _buildSummary(),
                    ],
                  ),
                ),
              ),
            ),

            // Navigation
            if (!isAiStep)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (canGoBack)
                      IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: NudgeTokens.textLow),
                      )
                    else
                      const SizedBox(width: 48),
                    _NextButton(
                      label: isLastStep ? 'LAUNCH' : 'CONTINUE',
                      onTap: _next,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Step builders ─────────────────────────────────────────────────────────

  Widget _buildWelcome() {
    return _StepLayout(
      emoji: '👋',
      title: 'Welcome to Nudge',
      subtitle:
          'Your private, AI-powered health companion.\nLocally stored. Intelligently guided.',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedSecurityShield(pulse: _pulseCtrl),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RestoreFromCloudScreen(
                    onRestored: () {
                      AppStorage.hasSeenOnboarding = true;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    onSkip: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.cloud_download_rounded, color: NudgeTokens.blue, size: 16),
            label: const Text('Restore from Cloud Backup', style: TextStyle(color: NudgeTokens.blue, fontSize: 13, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              backgroundColor: NudgeTokens.blue.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              showDialog(
                context: context, 
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator(color: NudgeTokens.purple)),
              );
              await MockDataService.populate();
              if (!mounted) return;
              Navigator.pop(context); // close dialog
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            icon: const Icon(Icons.bug_report_rounded, color: NudgeTokens.purple, size: 16),
            label: const Text('Developer Test Mode', style: TextStyle(color: NudgeTokens.purple, fontSize: 12)),
            style: TextButton.styleFrom(
              backgroundColor: NudgeTokens.purple.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleSelection() {
    final modules = {
      'gym':      (Icons.fitness_center_rounded,    'Gym & Workouts'),
      'food':     (Icons.restaurant_rounded,         'Nutrition & Calories'),
      'finance':  (Icons.account_balance_wallet_rounded, 'Money & Budget'),
      'movies':   (Icons.local_movies_rounded,       'Movies & Series'),
      'books':    (Icons.menu_book_rounded,           'Reading List'),
      'detox':    (Icons.timer_off_rounded,           'Digital Detox'),
      'pomodoro': (Icons.timer_rounded,               'Focus Timer'),
      'habits':   (Icons.check_box_rounded,           'Habit Tracker'),
      'health':   (Icons.monitor_heart_rounded,       'Health Center'),
    };

    return _StepLayout(
      emoji: '🛠️',
      title: 'Personalise',
      subtitle: 'Select the modules you want to focus on.',
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: modules.entries.map((e) {
          final selected = _selectedModules.contains(e.key);
          return GestureDetector(
            onTap: () {
              setState(() => selected
                  ? _selectedModules.remove(e.key)
                  : _selectedModules.add(e.key));
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              transform: Matrix4.identity()..scale(selected ? 1.02 : 1.0),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: selected
                    ? NudgeTokens.purple.withValues(alpha: 0.10)
                    : NudgeTokens.elevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? NudgeTokens.purple : NudgeTokens.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(e.value.$1,
                      color: selected
                          ? NudgeTokens.purple
                          : NudgeTokens.textLow,
                      size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      e.value.$2,
                      style: GoogleFonts.outfit(
                        color: selected
                            ? Colors.white
                            : NudgeTokens.textMid,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: selected
                        ? const Icon(Icons.check_circle_rounded,
                            key: ValueKey('check'),
                            color: NudgeTokens.purple,
                            size: 18)
                        : const SizedBox.shrink(key: ValueKey('none')),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFitnessGoals() {
    const goals = [
      (Icons.fitness_center_rounded,    NudgeTokens.gymB,   'Build Muscle'),
      (Icons.local_fire_department_rounded, NudgeTokens.amber, 'Lose Weight'),
      (Icons.speed_rounded,             NudgeTokens.blue,   'Improve Endurance'),
      (Icons.bolt_rounded,              NudgeTokens.purple, 'Increase Strength'),
      (Icons.self_improvement_rounded,  NudgeTokens.green,  'Flexibility & Mobility'),
      (Icons.emoji_events_rounded,      NudgeTokens.red,    'Sports Performance'),
    ];

    return _StepLayout(
      emoji: '🎯',
      title: 'Fitness Goals',
      subtitle: 'What do you want to achieve? Pick all that apply.',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: goals.map((g) {
                final selected = _fitnessGoals.contains(g.$3);
                return GestureDetector(
                  onTap: () {
                    setState(() => selected
                        ? _fitnessGoals.remove(g.$3)
                        : _fitnessGoals.add(g.$3));
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: selected
                          ? g.$2.withValues(alpha: 0.14)
                          : NudgeTokens.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? g.$2.withValues(alpha: 0.7)
                            : NudgeTokens.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(g.$1,
                            color: selected ? g.$2 : NudgeTokens.textLow,
                            size: 16),
                        const SizedBox(width: 8),
                        Text(
                          g.$3,
                          style: GoogleFonts.outfit(
                            color: selected ? Colors.white : NudgeTokens.textMid,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: NudgeTokens.elevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NudgeTokens.border),
              ),
              child: TextField(
                controller: _goalDescCtrl,
                maxLines: 4,
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 14, height: 1.5),
                decoration: InputDecoration(
                  hintText:
                      'Describe your goal in your own words…\ne.g. "I want to run a 5K in under 25 min by June"',
                  hintStyle: GoogleFonts.outfit(
                      color: NudgeTokens.textLow,
                      fontSize: 13,
                      height: 1.4),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTypes() {
    const activities = [
      (Icons.fitness_center_rounded,    NudgeTokens.gymB,   'Gym / Weights'),
      (Icons.home_rounded,              NudgeTokens.amber,  'Home Workout'),
      (Icons.accessibility_new_rounded, NudgeTokens.blue,   'Calisthenics'),
      (Icons.directions_run_rounded,    NudgeTokens.purple, 'Running / Cardio'),
      (Icons.music_note_rounded,        NudgeTokens.green,  'Zumba / Dance'),
      (Icons.self_improvement_rounded,  NudgeTokens.red,    'Yoga / Pilates'),
      (Icons.sports_martial_arts_rounded, NudgeTokens.protB, 'Martial Arts'),
    ];

    return _StepLayout(
      emoji: '🏃',
      title: 'Training Style',
      subtitle: 'How do you prefer to train? Pick all that apply.',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: activities.map((g) {
                final selected = _activityTypes.contains(g.$3);
                return GestureDetector(
                  onTap: () {
                    setState(() => selected
                        ? _activityTypes.remove(g.$3)
                        : _activityTypes.add(g.$3));
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: selected
                          ? g.$2.withValues(alpha: 0.14)
                          : NudgeTokens.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? g.$2.withValues(alpha: 0.7)
                            : NudgeTokens.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(g.$1,
                            color: selected ? g.$2 : NudgeTokens.textLow,
                            size: 16),
                        const SizedBox(width: 8),
                        Text(
                          g.$3,
                          style: GoogleFonts.outfit(
                            color: selected ? Colors.white : NudgeTokens.textMid,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: NudgeTokens.elevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NudgeTokens.border),
              ),
              child: TextField(
                controller: _activityDescCtrl,
                maxLines: 4,
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 14, height: 1.5),
                decoration: InputDecoration(
                  hintText:
                      'Any other activities? (e.g., swimming, cycling, bouldering)…',
                  hintStyle: GoogleFonts.outfit(
                      color: NudgeTokens.textLow,
                      fontSize: 13,
                      height: 1.4),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLevel() {
    final levels = [
      (Icons.eco_rounded,              NudgeTokens.green,  'Beginner',
       'New to training or returning after a long break'),
      (Icons.bolt_rounded,             NudgeTokens.amber,  'Intermediate',
       '6–18 months of consistent training'),
      (Icons.local_fire_department_rounded, NudgeTokens.red, 'Advanced',
       '2+ years of structured training'),
    ];

    return _StepLayout(
      emoji: '📊',
      title: 'Your Level',
      subtitle: 'Be honest — this shapes your progression targets.',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            ...levels.map((l) {
              final selected = _fitnessLevel == l.$3;
              return GestureDetector(
                onTap: () {
                  setState(() => _fitnessLevel = l.$3);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected
                        ? l.$2.withValues(alpha: 0.12)
                        : NudgeTokens.elevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? l.$2.withValues(alpha: 0.7)
                          : NudgeTokens.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: l.$2.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(l.$1, color: l.$2, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.$3,
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(l.$4,
                                style: GoogleFonts.outfit(
                                    color: NudgeTokens.textLow,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            color: l.$2, size: 20),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: NudgeTokens.elevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NudgeTokens.border),
              ),
              child: TextField(
                controller: _routineDescCtrl,
                maxLines: 3,
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 14, height: 1.5),
                decoration: InputDecoration(
                  hintText:
                      'Optional: describe your current routine…\ne.g. "3 days PPL, mostly machines"',
                  hintStyle: GoogleFonts.outfit(
                      color: NudgeTokens.textLow, fontSize: 13, height: 1.4),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymCommitment() {
    return _StepLayout(
      emoji: '💪',
      title: 'Weekly Commitment',
      subtitle: 'How many days will you train this week?',
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AnimatedDumbbell(days: _gymDays),
                const SizedBox(height: 20),
                Text(
                  '$_gymDays',
                  style: GoogleFonts.outfit(
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      color: NudgeTokens.purple,
                      height: 1.0),
                ),
                Text(
                  'DAYS / WEEK',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: NudgeTokens.textLow,
                      letterSpacing: 2,
                      fontSize: 12),
                ),
                const SizedBox(height: 40),
                Slider(
                  value: _gymDays.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  activeColor: NudgeTokens.purple,
                  inactiveColor: NudgeTokens.border,
                  onChanged: (v) {
                    setState(() => _gymDays = v.toInt());
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _gymDaysLabel(_gymDays),
                  style: GoogleFonts.outfit(
                      color: NudgeTokens.textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _gymDaysLabel(int days) {
    if (days <= 2) return 'Light schedule — ideal for beginners';
    if (days <= 4) return 'Solid commitment — great for progress';
    if (days <= 5) return 'High frequency — great results ahead';
    return 'Elite mode — make sure recovery is dialled in';
  }

  Widget _buildWaterGoal() {
    return _StepLayout(
      emoji: '💧',
      title: 'Hydration Goal',
      subtitle: 'Water is the fuel for your progress.',
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AnimatedWaterBottle(ml: _waterGoal),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _showWaterDialog,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_waterGoal',
                        style: GoogleFonts.outfit(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: NudgeTokens.blue,
                            height: 1.0),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_rounded, color: NudgeTokens.textLow, size: 20),
                    ],
                  ),
                ),
                Text(
                  'ML / DAY',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: NudgeTokens.textLow,
                      letterSpacing: 2,
                      fontSize: 12),
                ),
                const SizedBox(height: 36),
                Slider(
                  value: _waterGoal.toDouble().clamp(500.0, 5000.0),
                  min: 500,
                  max: 5000,
                  divisions: 45,
                  activeColor: NudgeTokens.blue,
                  inactiveColor: NudgeTokens.border,
                  onChanged: (v) {
                    setState(() => _waterGoal = v.toInt());
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the number to type an exact amount.',
                  style: GoogleFonts.outfit(
                      color: NudgeTokens.textLow, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiAgentSetup() {
    return _StepLayout(
      emoji: '🧠',
      title: 'AI Agent Setup',
      subtitle: 'Paste your Gemini API Key to activate intelligent planning.',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NudgeTokens.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NudgeTokens.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.key_rounded, color: NudgeTokens.purple, size: 32),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _geminiKeyCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                        hintText: 'AIzaSy...',
                        hintStyle: const TextStyle(color: NudgeTokens.textLow),
                        labelText: 'Gemini API Key',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your key is stored securely on-device and is never sent anywhere except directly to Google for inference.',
                    style: TextStyle(fontSize: 11, color: NudgeTokens.textMid, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Get an API key for free from Google AI Studio.',
                    style: TextStyle(fontSize: 12, color: NudgeTokens.textLow, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetGoal() {
    return _StepLayout(
      emoji: '💰',
      title: 'Monthly Budget',
      subtitle: 'Protect your future self.',
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AnimatedMoneyPot(amount: _budgetGoal),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _showBudgetDialog,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '£${_budgetGoal.toInt()}',
                        style: GoogleFonts.outfit(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: NudgeTokens.green,
                            height: 1.0),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_rounded, color: NudgeTokens.textLow, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TARGET MONTHLY SPEND',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: NudgeTokens.textLow,
                      letterSpacing: 2,
                      fontSize: 11),
                ),
                const SizedBox(height: 36),
                Slider(
                  value: _budgetGoal.toDouble().clamp(0.0, 5000.0),
                  min: 0,
                  max: 5000,
                  divisions: 100,
                  activeColor: NudgeTokens.green,
                  inactiveColor: NudgeTokens.border,
                  onChanged: (v) {
                    setState(() => _budgetGoal = v);
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the number to type an exact amount.',
                  style: GoogleFonts.outfit(
                      color: NudgeTokens.textLow, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBudgetDialog() {
    final ctrl = TextEditingController(text: _budgetGoal.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.elevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Target Monthly Spend',
          style: GoogleFonts.outfit(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.outfit(
              color: NudgeTokens.green, fontSize: 24, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixText: '£ ',
            prefixStyle: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 24),
            border: const UnderlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.green)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.green, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: NudgeTokens.textLow)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NudgeTokens.green,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                setState(() => _budgetGoal = val);
              }
              Navigator.pop(ctx);
            },
            child: Text('Save',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showWaterDialog() {
    final ctrl = TextEditingController(text: _waterGoal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NudgeTokens.elevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Target Hydration',
          style: GoogleFonts.outfit(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.outfit(
              color: NudgeTokens.blue, fontSize: 24, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            suffixText: ' ml',
            suffixStyle: GoogleFonts.outfit(color: NudgeTokens.textLow, fontSize: 24),
            border: const UnderlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.blue)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: NudgeTokens.blue, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: NudgeTokens.textLow)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NudgeTokens.blue,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final val = int.tryParse(ctrl.text);
              if (val != null) {
                setState(() => _waterGoal = val);
              }
              Navigator.pop(ctx);
            },
            child: Text('Save',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildAiProgression() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _generatingPlan
          ? _AiGeneratingView(
              statusText: _aiStatusText,
              pulse: _pulseCtrl,
            )
          : _AiPlanReadyView(
              plan: _aiPlan ?? '',
              onContinue: _next,
            ),
    );
  }

  Widget _buildSummary() {
    return _StepLayout(
      emoji: '🚀',
      title: 'You\'re ready',
      subtitle: 'Your personalised Nudge is set up and waiting.',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _SummaryRow(
              icon: Icons.check_circle_outline,
              color: NudgeTokens.purple,
              label: 'Modules',
              value: '${_selectedModules.length} active',
            ),
            if (_fitnessGoals.isNotEmpty)
              _SummaryRow(
                icon: Icons.flag_rounded,
                color: NudgeTokens.gymB,
                label: 'Goals',
                value: _fitnessGoals.take(2).join(', ') +
                    (_fitnessGoals.length > 2 ? '…' : ''),
              ),
            if (_activityTypes.isNotEmpty)
              _SummaryRow(
                icon: Icons.directions_run_rounded,
                color: NudgeTokens.green,
                label: 'Activities',
                value: _activityTypes.take(2).join(', ') +
                    (_activityTypes.length > 2 ? '…' : ''),
              ),
            _SummaryRow(
              icon: Icons.person_rounded,
              color: NudgeTokens.amber,
              label: 'Level',
              value: _fitnessLevel,
            ),
            _SummaryRow(
              icon: Icons.fitness_center_rounded,
              color: NudgeTokens.purple,
              label: 'Training',
              value: '$_gymDays days/week',
            ),
            _SummaryRow(
              icon: Icons.water_drop_rounded,
              color: NudgeTokens.blue,
              label: 'Hydration',
              value: '${_waterGoal}ml/day',
            ),
            _SummaryRow(
              icon: Icons.account_balance_wallet_rounded,
              color: NudgeTokens.green,
              label: 'Budget',
              value: '£${_budgetGoal.toInt()}/mo',
            ),
            if (_aiPlan != null)
              _SummaryRow(
                icon: Icons.auto_awesome_rounded,
                color: NudgeTokens.purple,
                label: 'AI Plan',
                value: '8-week progression ready',
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Generating View — animated loading screen
// ─────────────────────────────────────────────────────────────────────────────

class _AiGeneratingView extends StatelessWidget {
  final String statusText;
  final AnimationController pulse;
  const _AiGeneratingView({required this.statusText, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing brain icon
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: NudgeTokens.purple
                      .withValues(alpha: 0.15 + 0.2 * pulse.value),
                  blurRadius: 40 + 20 * pulse.value,
                  spreadRadius: 4 + 6 * pulse.value,
                ),
              ],
              gradient: RadialGradient(
                colors: [
                  NudgeTokens.purple.withValues(alpha: 0.2 + 0.1 * pulse.value),
                  NudgeTokens.purple.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 64, color: NudgeTokens.purple),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'Building Your Plan',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            statusText,
            key: ValueKey(statusText),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 15,
                color: NudgeTokens.textMid,
                height: 1.4),
          ),
        ),
        const SizedBox(height: 40),
        // Progress dots
        _PulsingDots(pulse: pulse),
        const SizedBox(height: 48),
        // AI capability chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _AiChip(Icons.bolt_rounded, 'Progressive Overload'),
            _AiChip(Icons.show_chart_rounded, 'Load Periodisation'),
            _AiChip(Icons.restore_rounded, 'Recovery Protocols'),
            _AiChip(Icons.emoji_events_rounded, 'Goal-Specific Targets'),
          ],
        ),
      ],
    );
  }
}

class _PulsingDots extends StatelessWidget {
  final AnimationController pulse;
  const _PulsingDots({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final offset = i / 3.0;
          final v = (math.sin((pulse.value + offset) * math.pi * 2) + 1) / 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8 + 4 * v,
            height: 8 + 4 * v,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NudgeTokens.purple.withValues(alpha: 0.4 + 0.6 * v),
            ),
          );
        }),
      ),
    );
  }
}

class _AiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AiChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: NudgeTokens.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: NudgeTokens.purple),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: NudgeTokens.textMid,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Plan Ready View
// ─────────────────────────────────────────────────────────────────────────────

class _AiPlanReadyView extends StatelessWidget {
  final String plan;
  final VoidCallback onContinue;
  const _AiPlanReadyView({required this.plan, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NudgeTokens.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: NudgeTokens.purple, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Progression Plan',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                Text('AI-generated · personalised for you',
                    style: GoogleFonts.outfit(
                        color: NudgeTokens.textLow, fontSize: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: NudgeTokens.elevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: NudgeTokens.purple.withValues(alpha: 0.2)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _MarkdownText(plan),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: NudgeTokens.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text('LOOKS GREAT',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Very lightweight markdown renderer — handles ## headers and - bullets.
class _MarkdownText extends StatelessWidget {
  final String text;
  const _MarkdownText(this.text);

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              line.substring(3),
              style: GoogleFonts.outfit(
                  color: NudgeTokens.purple,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.3),
            ),
          );
        }
        if (line.startsWith('**') && line.endsWith('**')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line.replaceAll('**', ''),
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
            ),
          );
        }
        if (line.startsWith('- ') || line.startsWith('* ')) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: NudgeTokens.purple,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _stripMarkdown(line.substring(2)),
                    style: GoogleFonts.outfit(
                        color: NudgeTokens.textMid,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }
        if (line.trim().isEmpty) return const SizedBox(height: 4);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _stripMarkdown(line),
            style: GoogleFonts.outfit(
                color: NudgeTokens.textMid, fontSize: 12, height: 1.5),
          ),
        );
      }).toList(),
    );
  }

  String _stripMarkdown(String s) =>
      s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!);
}

// ─────────────────────────────────────────────────────────────────────────────
// Next button
// ─────────────────────────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: NudgeTokens.purple,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: NudgeTokens.purple.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Micro-animations
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedSecurityShield extends StatelessWidget {
  final AnimationController pulse;
  const _AnimatedSecurityShield({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, 12 * math.sin(pulse.value * math.pi)),
        child: Container(
          padding: const EdgeInsets.all(44),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: NudgeTokens.purple
                    .withValues(alpha: 0.1 + 0.12 * pulse.value),
                blurRadius: 50 + 20 * pulse.value,
                spreadRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.security_rounded,
              size: 96, color: NudgeTokens.purple),
        ),
      ),
    );
  }
}

class _AnimatedWaterBottle extends StatefulWidget {
  final int ml;
  const _AnimatedWaterBottle({required this.ml});

  @override
  State<_AnimatedWaterBottle> createState() => _AnimatedWaterBottleState();
}

class _AnimatedWaterBottleState extends State<_AnimatedWaterBottle>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetFill = (widget.ml / 3000).clamp(0.2, 1.0);
    
    return SizedBox(
      height: 130,
      width: 72,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: NudgeTokens.border, width: 2.5),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (context, _) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: targetFill, end: targetFill),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, fill, _) {
                    return CustomPaint(
                      size: const Size(67, 125),
                      painter: _WaterWavePainter(
                        fillLevel: fill,
                        phase: _waveCtrl.value * 2 * math.pi,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Positioned(
            top: 16,
            child: Icon(Icons.water_drop_rounded,
                color: Colors.white24, size: 22),
          ),
        ],
      ),
    );
  }
}

class _WaterWavePainter extends CustomPainter {
  final double fillLevel;
  final double phase;

  _WaterWavePainter({required this.fillLevel, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    if (fillLevel <= 0.0) return;

    final waterHeight = size.height * fillLevel;
    final topY = size.height - waterHeight;

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, topY),
        Offset(0, size.height),
        [
          NudgeTokens.blue.withValues(alpha: 0.5),
          NudgeTokens.blue.withValues(alpha: 0.8),
        ],
      );

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, topY);

    // Draw the sine wave
    final waveAmplitude = 4.0;
    final waveFrequency = 1.5; // How many waves fit in the width

    for (double x = 0; x <= size.width; x++) {
      // Normalise x from 0 to 2*PI, multiply by frequency, and add phase
      final normalizedX = (x / size.width) * 2 * math.pi;
      final y = topY + math.sin(normalizedX * waveFrequency + phase) * waveAmplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaterWavePainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel || oldDelegate.phase != phase;
  }
}

class _AnimatedDumbbell extends StatefulWidget {
  final int days;
  const _AnimatedDumbbell({required this.days});

  @override
  State<_AnimatedDumbbell> createState() => _AnimatedDumbbellState();
}

class _AnimatedDumbbellState extends State<_AnimatedDumbbell>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _initAnim();
  }

  void _initAnim() {
    // Speed up the rep animation based on how many days they train!
    final ms = 1100 - (widget.days * 110);
    _ctrl = AnimationController(
        vsync: this, duration: Duration(milliseconds: ms.toInt()))
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AnimatedDumbbell old) {
    super.didUpdateWidget(old);
    if (old.days != widget.days) {
      final ms = 1100 - (widget.days * 110);
      _ctrl.duration = Duration(milliseconds: ms.toInt());
      if (_ctrl.isAnimating) {
        // Keeps it moving at the new speed without snapping
        _ctrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Intensity of the curl increases slightly with days too
    final maxAngle = 0.2 + (widget.days * 0.05);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Smooth sine-wave curl
        final curve = Curves.easeInOutSine.transform(_ctrl.value);
        final angle = curve * maxAngle;
        final yOff = curve * -12.0; // Lift up slightly as it curls

        return Transform.translate(
          offset: Offset(0, yOff),
          child: Transform.rotate(
            angle: angle,
            child: Container(
              padding: const EdgeInsets.all(34),
              decoration: BoxDecoration(
                color: NudgeTokens.purple.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: NudgeTokens.purple.withValues(alpha: 0.1 * curve),
                    blurRadius: 16 * curve,
                    spreadRadius: 2,
                  )
                ]
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 64, color: NudgeTokens.purple),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedMoneyPot extends StatefulWidget {
  final double amount;
  const _AnimatedMoneyPot({required this.amount});

  @override
  State<_AnimatedMoneyPot> createState() => _AnimatedMoneyPotState();
}

class _AnimatedMoneyPotState extends State<_AnimatedMoneyPot>
    with TickerProviderStateMixin {
  final List<_Coin> _coins = [];
  late AnimationController _wobbleCtrl;

  @override
  void initState() {
    super.initState();
    _wobbleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didUpdateWidget(_AnimatedMoneyPot old) {
    super.didUpdateWidget(old);
    if (widget.amount != old.amount) {
      // Add a coin dropping from the top into the piggy bank slot
      // We keep a narrow x-spread so it aims near the top slot
      final randX = math.Random().nextDouble() * 20 - 10;
      final randRot = math.Random().nextDouble() * math.pi;
      
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
          
      final coin = _Coin(xOffset: randX, rotation: randRot, ctrl: ctrl);
      _coins.add(coin);
      ctrl.forward(from: 0).then((_) {
        // Clean up old coins to avoid infinite memory growth
        if (mounted && _coins.length > 10) {
           final oldCoin = _coins.removeAt(0);
           oldCoin.ctrl.dispose();
        }
      });
      
      // Wobble the pot
      _wobbleCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wobbleCtrl.dispose();
    for (var c in _coins) {
      c.ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: 140,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Falling coins
          ..._coins.map((c) {
            return AnimatedBuilder(
              animation: c.ctrl,
              builder: (_, __) {
                final progress = c.ctrl.value;
                // Drop from high above (-150) down to the piggy bank slot (approx -60 to -80)
                final yOff = -150 + (80 * Curves.easeInQuad.transform(progress));
                // Rapidly fade out in the last 20% to look like it entered the slot
                final op = (1.0 - progress) * 3.0;
                return Transform.translate(
                  offset: Offset(c.xOffset, yOff),
                  child: Transform.rotate(
                    angle: c.rotation + (math.pi * progress),
                    child: Opacity(
                      opacity: op.clamp(0.0, 1.0),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: NudgeTokens.green,
                          border: Border.all(color: Colors.yellowAccent.withValues(alpha: 0.6), width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: NudgeTokens.green.withValues(alpha: 0.3),
                              blurRadius: 6,
                            )
                          ]
                        ),
                        child: const Center(
                           child: Text('£', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          // Giant Piggy Bank with wobble effect
          AnimatedBuilder(
            animation: _wobbleCtrl,
            builder: (_, __) {
              final squeeze = math.sin(_wobbleCtrl.value * math.pi) * 0.12;
              return Transform.scale(
                scaleX: 1.0 + squeeze,
                scaleY: 1.0 - squeeze,
                child: Container(
                  height: 110,
                  width: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: NudgeTokens.green.withValues(alpha: 0.15 + (squeeze * 1.5)),
                        blurRadius: 40 + (squeeze * 100),
                        spreadRadius: 2,
                      )
                    ]
                  ),
                  child: const Center(
                    child: Icon(Icons.savings_rounded,
                        color: NudgeTokens.green, size: 100),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Coin {
  final double xOffset;
  final double rotation;
  final AnimationController ctrl;
  _Coin({required this.xOffset, required this.rotation, required this.ctrl});
}

// ─────────────────────────────────────────────────────────────────────────────
// Utils
// ─────────────────────────────────────────────────────────────────────────────

class _StepLayout extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepLayout({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
                fontSize: 14,
                color: NudgeTokens.textMid,
                height: 1.45),
          ),
          const SizedBox(height: 28),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _SummaryRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 14),
          Text(label,
              style: GoogleFonts.outfit(
                  color: NudgeTokens.textMid,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
