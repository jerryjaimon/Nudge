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
import 'models/category_budget.dart';
import 'models/savings_jar.dart';
import 'models/jar_transfer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(CategoryBudgetAdapter());
  if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(SavingsJarAdapter());
  if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(JarTransferAdapter());
  if (!Hive.isAdapterRegistered(13)) Hive.registerAdapter(JarTransferDirectionAdapter());
  await AppStorage.init();
  await DetoxService.instance.init();
  await Firebase.initializeApp();
  await Workmanager().initialize(callbackDispatcher);
  await AutoBackupService.rescheduleIfEnabled();
  runApp(const NudgeApp());
  WidgetService.updateAll();
}
