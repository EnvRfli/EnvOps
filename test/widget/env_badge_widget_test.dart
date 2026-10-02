import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/domain/models/server_config.dart';
import 'package:env_ops/presentation/widgets/env_badge.dart';

void main() {
  testWidgets('EnvBadge displays PRODUCTION label and shield icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EnvBadge(environment: ServerEnvironment.production),
        ),
      ),
    );

    expect(find.text('PRODUCTION'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
  });

  testWidgets('EnvBadge displays DEVELOPMENT label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EnvBadge(environment: ServerEnvironment.development),
        ),
      ),
    );

    expect(find.text('DEVELOPMENT'), findsOneWidget);
  });
}
