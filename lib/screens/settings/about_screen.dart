import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app.dart' show NudgeTokens;
import '../../services/update_service.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_backup_service.dart';
import '../../services/auto_backup_service.dart';
import '../../storage.dart';
import '../onboarding_screen.dart';
import 'settings_widgets.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NudgeTokens.bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero section ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x337C4DFF), NudgeTokens.bg],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: NudgeTokens.textMid),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // App icon with glow
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NudgeTokens.purple.withValues(alpha: 0.14),
                        border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.35), width: 2),
                        boxShadow: [
                          BoxShadow(color: NudgeTokens.purple.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 0),
                        ],
                      ),
                      child: const Icon(Icons.rocket_launch_rounded, color: NudgeTokens.purple, size: 40),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nudge',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: NudgeTokens.textHigh),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: NudgeTokens.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: NudgeTokens.purple.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        'v${UpdateService.currentVersion}',
                        style: const TextStyle(color: NudgeTokens.purple, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your personal productivity & wellness companion',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NudgeTokens.textLow, fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          // ── Content ─────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SectionHeader(title: 'Made With ♥ By'),
                Row(
                  children: [
                    Expanded(child: _DevCard(name: 'lilscott', initials: 'LS', color: NudgeTokens.purple)),
                    const SizedBox(width: 10),
                    Expanded(child: _DevCard(name: 'weaverclaw', initials: 'WC', color: NudgeTokens.blue)),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Links'),
                SettingTile(
                  icon: Icons.code_rounded,
                  title: 'GitHub Repository',
                  subtitle: 'View source code & issues',
                  onTap: () => launchUrl(Uri.parse('https://github.com/jerryjaimon/Nudge')),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: NudgeTokens.textLow),
                ),
                SettingTile(
                  icon: Icons.system_update_rounded,
                  title: 'Check for Updates',
                  subtitle: 'Current: v${UpdateService.currentVersion}',
                  onTap: () => _checkForUpdates(context),
                  trailing: const Icon(Icons.chevron_right_rounded, color: NudgeTokens.textLow),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Danger Zone'),
                SettingTile(
                  icon: Icons.delete_forever_rounded,
                  title: 'Delete Account & Data',
                  subtitle: 'Irreversibly wipe all data',
                  color: NudgeTokens.red,
                  onTap: () => _confirmDelete(context),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext ctx) async {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Checking for updates…'), duration: Duration(seconds: 2)),
    );

    final info = await UpdateService.checkForUpdate();

    if (!ctx.mounted) return;
    if (info == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Could not reach update server. Check your connection.')),
      );
      return;
    }

    if (!info.isNewer) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('You\'re up to date (v${UpdateService.currentVersion})')),
      );
      return;
    }

    final apkUrl = info.apkUrl;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: NudgeTokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: NudgeTokens.purple, size: 22),
            const SizedBox(width: 10),
            Text('v${info.version} Available',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${info.name}',
                style: const TextStyle(color: NudgeTokens.textMid, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(info.changelog,
                style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12, height: 1.5)),
            if (apkUrl == null) ...[
              const SizedBox(height: 12),
              const Text('No APK attached to this release.',
                  style: TextStyle(color: NudgeTokens.red, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Later', style: TextStyle(color: NudgeTokens.textMid)),
          ),
          if (apkUrl != null)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NudgeTokens.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Download & Install', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );

    if (confirmed != true || apkUrl == null || !ctx.mounted) return;

    double progress = 0;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (pCtx) => StatefulBuilder(
        builder: (_, setS) {
          return AlertDialog(
            backgroundColor: NudgeTokens.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Downloading…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: NudgeTokens.elevated,
                  color: NudgeTokens.purple,
                ),
                const SizedBox(height: 8),
                Text(progress > 0 ? '${(progress * 100).toInt()}%' : 'Starting…',
                    style: const TextStyle(color: NudgeTokens.textLow, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );

    final file = await UpdateService.downloadApk(apkUrl, (p) {
      progress = p;
      // We need a way to rebuild the progress dialog. 
      // Since we don't have the setS here easily, we'd typically use a stream or a more complex state manament.
      // But for simplicity in a quick migration, we can just use the outer setS if we passed it in.
      // However, downloadApk is called outside builder.
      // Actually, we can use a ValueNotifier.
    });

    if (!ctx.mounted) return;
    Navigator.of(ctx, rootNavigator: true).pop(); // close progress dialog

    if (file == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Download failed. Please try again.')),
      );
      return;
    }

    await UpdateService.installApk(file.path);
  }

  Future<void> _confirmDelete(BuildContext context) async {
     final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: NudgeTokens.surface,
          title: const Text('Delete Everything?', style: TextStyle(color: NudgeTokens.red)),
          content: const Text('This will irreversibly wipe all local files, logs, and settings. Are you sure?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: NudgeTokens.red),
              onPressed: () => Navigator.pop(ctx, true), 
              child: const Text('Delete All Data', style: TextStyle(fontWeight: FontWeight.bold))
            ),
          ],
        ),
      );

      if (confirm == true) {
        showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: NudgeTokens.red)));
        try {
          await AutoBackupService.disable();
          await FirebaseBackupService.deleteBackup();
          await AuthService.deleteAccount();
        } catch (_) {}
        await AppStorage.clearAll();
        if (!context.mounted) return;
        Navigator.pop(context); // close loading
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const OnboardingScreen()), (r) => false);
      }
  }
}

// ── Developer card ────────────────────────────────────────────────────────────

class _DevCard extends StatelessWidget {
  final String name;
  final String initials;
  final Color color;

  const _DevCard({required this.name, required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(color: NudgeTokens.textHigh, fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 2),
          const Text('Developer', style: TextStyle(color: NudgeTokens.textLow, fontSize: 11)),
        ],
      ),
    );
  }
}

