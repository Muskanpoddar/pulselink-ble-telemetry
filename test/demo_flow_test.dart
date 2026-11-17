import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_link/app/app.dart';

void main() {
  testWidgets('demo mode lists the simulated peripherals', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PulseLinkApp()));
    await tester.pump();

    // Demo mode on.
    await tester.tap(find.byType(Switch));
    await tester.pump();

    // Scan.
    await tester.tap(find.text('SCAN FOR DEVICES'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('ESP32 Sensor Node'), findsOneWidget);
    expect(find.text('Demo Sensor Device'), findsOneWidget);

    // Open the details of the first device.
    await tester.tap(find.text('ESP32 Sensor Node'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('CONNECT'), findsOneWidget);

    // Let the scan timeout fire so no timer is left pending.
    await tester.pump(const Duration(seconds: 11));
  });
}
