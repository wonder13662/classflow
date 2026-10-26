import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'classflow_app.dart';
import 'config/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironment.parse(
    const String.fromEnvironment('CLASSFLOW_ENV', defaultValue: 'development'),
  );
  final options = firebaseOptionsFromEnvironment();
  if (options != null) {
    await Firebase.initializeApp(options: options);
  }
  runApp(ClassFlowApp(environment: environment));
}
