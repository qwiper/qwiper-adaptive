import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwiper_adaptive/qwiper_adaptive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.qwiper.adaptive/resources');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'built-in Android probe uses the public channel contract',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'readResources');
        expect(call.arguments, isNull);
        return <String, Object>{
          'logicalProcessors': 8,
          'isLowRamDevice': false,
          'memoryClassMb': 512,
          'totalMemoryBytes': 8 * 1024 * 1024 * 1024,
          'availableStorageBytes': 0,
        };
      });
      final reading = await ResourceDetector().read();
      expect(reading.status, ResourceReadStatus.available);
      expect(reading.resources.availableStorageBytes, 0);
      expect(
        ResourcePolicy().evaluate(reading.resources).isStorageConstrained,
        isTrue,
      );
    },
    skip: kIsWeb ? 'The built-in probe is native Android only.' : false,
  );

  test(
    'web never invokes the native probe with an Android target',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        return null;
      });
      final reading = await ResourceDetector().read();
      expect(reading.status, ResourceReadStatus.unsupported);
      expect(reading.resources, const DeviceResources.unknown());
      expect(calls, 0);
    },
    skip: !kIsWeb ? 'Requires the actual web runtime.' : false,
  );

  test('unsupported platforms do not invoke the native channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return null;
    });
    final reading = await ResourceDetector().read();
    expect(reading.status, ResourceReadStatus.unsupported);
    expect(reading.resources, const DeviceResources.unknown());
    expect(calls, 0);
  });

  test('custom reader works regardless of built-in platform support', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final reading = await ResourceDetector(
      reader: () async => <String, Object>{'logicalProcessors': 4},
    ).read();
    expect(reading.status, ResourceReadStatus.partial);
    expect(reading.resources.logicalProcessors, 4);
    expect(reading.resources.totalMemoryBytes, isNull);
  });

  test('invalid fields are unknown while valid observations survive', () async {
    final reading = await ResourceDetector(
      reader: () async => <String, Object>{
        'logicalProcessors': '8',
        'isLowRamDevice': 1,
        'memoryClassMb': -10,
        'totalMemoryBytes': 0,
        'availableStorageBytes': 0,
      },
    ).read();
    expect(reading.status, ResourceReadStatus.invalidData);
    expect(reading.resources, DeviceResources(availableStorageBytes: 0));
  });

  for (final payload in <Object>[12, 'data', <Object>[]]) {
    test('rejects non-map payload $payload', () async {
      final reading = await ResourceDetector(
        reader: () async => payload,
      ).read();
      expect(reading.status, ResourceReadStatus.invalidData);
      expect(reading.resources, const DeviceResources.unknown());
    });
  }

  test(
    'fractional numeric observations are not rounded into hardware facts',
    () async {
      final reading = await ResourceDetector(
        reader: () async => <String, Object>{
          'logicalProcessors': 8.5,
          'memoryClassMb': double.nan,
          'availableStorageBytes': -1,
        },
      ).read();
      expect(reading.status, ResourceReadStatus.invalidData);
      expect(reading.resources, const DeviceResources.unknown());
    },
  );

  test('missing plugin is an explicit unavailable result', () async {
    final reading = await ResourceDetector(
      reader: () async => throw MissingPluginException(),
    ).read();
    expect(reading.status, ResourceReadStatus.unavailable);
  });

  test(
    'non-finite numbers cannot become device observations on the web',
    () async {
      final reading = await ResourceDetector(
        reader: () async => <String, Object>{
          'logicalProcessors': double.infinity,
          'memoryClassMb': double.negativeInfinity,
          'totalMemoryBytes': double.infinity,
          'availableStorageBytes': double.infinity,
          'isLowRamDevice': false,
        },
      ).read();
      expect(reading.status, ResourceReadStatus.invalidData);
      expect(reading.resources, DeviceResources(isLowRamDevice: false));
    },
  );

  test('platform errors do not expose raw diagnostic details', () async {
    final reading = await ResourceDetector(
      reader: () async {
        throw PlatformException(
          code: 'read_failed',
          message: 'private diagnostic',
        );
      },
    ).read();
    expect(reading.status, ResourceReadStatus.unavailable);
    expect(reading.resources, const DeviceResources.unknown());
  });

  test(
    'null and empty payloads are unavailable, not measured zeroes',
    () async {
      for (final value in <Object?>[null, <String, Object>{}]) {
        final reading = await ResourceDetector(
          reader: () async => value,
        ).read();
        expect(reading.status, ResourceReadStatus.unavailable);
      }
    },
  );

  test('a stalled probe completes at its deadline', () async {
    final pending = Completer<Object?>();
    final reading = await ResourceDetector(
      reader: () => pending.future,
      timeout: const Duration(milliseconds: 10),
    ).read();
    expect(reading.status, ResourceReadStatus.timedOut);
    pending.complete(<String, Object>{'logicalProcessors': 8});
    expect(reading.resources, const DeviceResources.unknown());
  });

  test('unexpected custom reader programming errors remain visible', () async {
    expect(
      ResourceDetector(reader: () async => throw StateError('bug')).read(),
      throwsStateError,
    );
  });

  test('zero and negative deadlines are rejected outside assertions', () {
    expect(() => ResourceDetector(timeout: Duration.zero), throwsArgumentError);
    expect(
      () => ResourceDetector(timeout: const Duration(seconds: -1)),
      throwsArgumentError,
    );
  });
}
