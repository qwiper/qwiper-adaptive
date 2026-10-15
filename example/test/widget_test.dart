import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwiper_adaptive/qwiper_adaptive.dart';
import 'package:qwiper_adaptive_example/main.dart';

void main() {
  testWidgets('switching synthetic profiles updates the actual effect', (
    tester,
  ) async {
    await tester.pumpWidget(const AdaptiveDemoApp());
    expect(find.text('Profil balanced'), findsOneWidget);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('scenario-Modeste')));
    await tester.pumpAndSettle();
    expect(find.text('Profil low'), findsOneWidget);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
  });

  testWidgets('device read replaces simulation and identifies partial data', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdaptiveDemoApp(
        detector: ResourceDetector(
          reader: () async => <String, Object>{'isLowRamDevice': true},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('read-device')));
    await tester.pumpAndSettle();
    expect(find.text('Source : sonde • partial'), findsOneWidget);
    expect(find.text('Profil low'), findsOneWidget);
  });

  testWidgets('small viewport and enlarged text do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const AdaptiveDemoApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending reads disable competing input until a result arrives', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    var calls = 0;
    await tester.pumpWidget(
      AdaptiveDemoApp(
        detector: ResourceDetector(
          reader: () {
            calls++;
            return pending.future;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('read-device')));
    await tester.pump();
    expect(calls, 1);
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.onSelected, isNull);
    }
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('low-storage')))
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('read-device')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('scenario-Modeste')));
    await tester.pump();
    expect(find.text('Profil balanced'), findsOneWidget);
    pending.complete(<String, Object>{'isLowRamDevice': true});
    await tester.pumpAndSettle();
    expect(find.text('Source : sonde • partial'), findsOneWidget);
    expect(find.text('Profil low'), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.byKey(const ValueKey('scenario-Élevé')));
    await tester.pumpAndSettle();
    expect(find.text('Source : simulation'), findsOneWidget);
    expect(find.text('Profil high'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('low-storage')))
          .onChanged,
      isNotNull,
    );
  });

  testWidgets(
    'failed reads preserve the simulation and allow another attempt',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        AdaptiveDemoApp(
          detector: ResourceDetector(
            reader: () async {
              if (++calls == 1) throw Exception('private-reader-details');
              return <String, Object>{'isLowRamDevice': true};
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('low-storage')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('read-device')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('read-error')), findsOneWidget);
      expect(find.textContaining('private-reader-details'), findsNothing);
      expect(find.text('Source : simulation'), findsOneWidget);
      expect(find.text('Profil balanced'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('low-storage')))
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('read-device')))
            .onPressed,
        isNotNull,
      );
      for (final chip in tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      )) {
        expect(chip.onSelected, isNotNull);
      }

      await tester.tap(find.byKey(const ValueKey('read-device')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byKey(const ValueKey('read-error')), findsNothing);
      expect(find.text('Source : sonde • partial'), findsOneWidget);
      expect(find.text('Profil low'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unexpected reader error preserves the last measured data', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      AdaptiveDemoApp(
        detector: ResourceDetector(
          reader: () async {
            if (++calls > 1) throw StateError('private-error-details');
            return <String, Object>{'isLowRamDevice': true};
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('read-device')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('read-device')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('read-error')), findsOneWidget);
    expect(find.textContaining('private-error-details'), findsNothing);
    expect(find.text('Source : sonde • partial'), findsOneWidget);
    expect(find.text('Profil low'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('read-device')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('scenario-Élevé')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('read-error')), findsNothing);
    expect(find.text('Source : simulation'), findsOneWidget);
    expect(find.text('Profil high'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('measured data clears the synthetic storage constraint', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdaptiveDemoApp(
        detector: ResourceDetector(
          reader: () async => <String, Object>{
            'availableStorageBytes': 16 * 1024 * 1024 * 1024,
          },
        ),
      ),
    );
    final storageSwitch = find.byKey(const ValueKey('low-storage'));
    await tester.tap(storageSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(storageSwitch).value, isTrue);

    await tester.tap(find.byKey(const ValueKey('read-device')));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(storageSwitch).value, isFalse);
    expect(tester.widget<SwitchListTile>(storageSwitch).onChanged, isNull);
    expect(find.text('16.0 Gio'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scenario-Élevé')));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(storageSwitch).value, isFalse);
    expect(tester.widget<SwitchListTile>(storageSwitch).onChanged, isNotNull);
    expect(find.text('64.0 Gio'), findsOneWidget);
  });
}
