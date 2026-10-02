import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:env_ops/domain/models/server_config.dart';
import 'package:env_ops/presentation/screens/docker/restart_confirmation_dialog.dart';

void main() {
  testWidgets('RestartConfirmationDialog blocks restart on Production until strict confirmation typed', (tester) async {
    final prodServer = ServerConfig(
      id: 'prod_1',
      name: 'Production Cluster',
      hostname: '100.84.12.19',
      username: 'cas',
      environment: ServerEnvironment.production,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RestartConfirmationDialog(
            server: prodServer,
            targetName: 'api_gateway_service',
            actionDescription: 'Restart Container',
          ),
        ),
      ),
    );

    expect(find.text('Restart Container?'), findsOneWidget);
    expect(find.text('api_gateway_service'), findsOneWidget);
    expect(find.text('PRODUCTION'), findsOneWidget);

    // Initial state: RESTART button is disabled
    final restartBtnFinder = find.widgetWithText(ElevatedButton, 'RESTART');
    expect(restartBtnFinder, findsOneWidget);
    ElevatedButton button = tester.widget(restartBtnFinder);
    expect(button.onPressed, isNull);

    // Tap checkbox acknowledgment
    final checkboxFinder = find.byType(Checkbox);
    await tester.tap(checkboxFinder);
    await tester.pump();

    // Still disabled because text has not been typed for Production
    button = tester.widget(restartBtnFinder);
    expect(button.onPressed, isNull);

    // Enter confirmation text
    final textFieldFinder = find.byType(TextField);
    await tester.enterText(textFieldFinder, 'CONFIRM RESTART');
    await tester.pump();

    // Now button should be enabled!
    button = tester.widget(restartBtnFinder);
    expect(button.onPressed, isNotNull);
  });
}
