// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

import 'package:provider/provider.dart';
import 'package:frontend/core/providers/user_provider.dart';
import 'package:frontend/core/providers/operational_provider.dart';
import 'package:frontend/presentation/screens/home_screen.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => OperationalProvider()),
        ],
        child: const SFCpcApp(),
      ),
    );

    // Verify that the app launches by checking for the main navigation tabs.
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
