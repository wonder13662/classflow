import 'package:classflow/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment.parse', () {
    test('maps short and canonical values', () {
      expect(AppEnvironment.parse('dev'), AppEnvironment.development);
      expect(AppEnvironment.parse('development'), AppEnvironment.development);
      expect(AppEnvironment.parse('stage'), AppEnvironment.stage);
      expect(AppEnvironment.parse('prod'), AppEnvironment.production);
      expect(AppEnvironment.parse('production'), AppEnvironment.production);
    });

    test('rejects unsupported values with a useful message', () {
      expect(
        () => AppEnvironment.parse('preview'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('CLASSFLOW_ENV'),
          ),
        ),
      );
    });
  });
}
