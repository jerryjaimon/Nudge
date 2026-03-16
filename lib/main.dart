import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'storage.dart';
import 'app.dart';
import 'utils/detox_service.dart';
import 'utils/notification_service.dart';
import 'services/widget_service.dart';
import 'services/auto_backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await Hive.initFlutter();
  await AppStorage.init();
  await DetoxService.instance.init();
  await Firebase.initializeApp();
  await Workmanager().initialize(callbackDispatcher);
  AutoBackupService.rescheduleIfEnabled();
  runApp(const NudgeApp());
  WidgetService.updateAll();
}
