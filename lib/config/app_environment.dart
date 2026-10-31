import 'package:firebase_core/firebase_core.dart';

enum AppEnvironment {
  development('development'),
  stage('stage'),
  production('production');

  const AppEnvironment(this.value);

  final String value;

  static AppEnvironment parse(String input) {
    return switch (input.trim().toLowerCase()) {
      'dev' || 'development' => AppEnvironment.development,
      'stage' => AppEnvironment.stage,
      'prod' || 'production' => AppEnvironment.production,
      _ => throw FormatException(
        '지원하지 않는 CLASSFLOW_ENV 값입니다: $input. '
        'development, stage, production 중 하나를 사용하세요.',
      ),
    };
  }
}

FirebaseOptions? firebaseOptionsFromEnvironment() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  if ([
    apiKey,
    appId,
    messagingSenderId,
    projectId,
  ].every((value) => value.isEmpty)) {
    return null;
  }
  if ([
    apiKey,
    appId,
    messagingSenderId,
    projectId,
  ].any((value) => value.isEmpty)) {
    throw StateError('Firebase 설정의 필수 값이 일부 누락되었습니다.');
  }

  return const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    measurementId: String.fromEnvironment('FIREBASE_MEASUREMENT_ID'),
    iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  );
}
