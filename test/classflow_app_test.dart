import 'package:classflow/classflow_app.dart';
import 'package:classflow/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the ClassFlow starter screen without Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ClassFlowApp(environment: AppEnvironment.development),
    );

    expect(find.text('ClassFlow'), findsOneWidget);
    expect(find.text('Environment: development'), findsOneWidget);
  });
}
