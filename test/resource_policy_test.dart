import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwiper_adaptive/qwiper_adaptive.dart';

const _mib = 1024 * 1024;
const _gib = 1024 * _mib;

void main() {
  final policy = ResourcePolicy();

  group('default tier decisions', () {
    final cases =
        <
          ({
            String name,
            DeviceResources resources,
            ResourceTier tier,
            ResourceDecisionReason reason,
          })
        >[
          (
            name: 'unknown capacity starts cautiously',
            resources: const DeviceResources.unknown(),
            tier: ResourceTier.low,
            reason: ResourceDecisionReason.unknownResources,
          ),
          (
            name: 'storage and a negative low-RAM flag do not prove capacity',
            resources: DeviceResources(
              isLowRamDevice: false,
              availableStorageBytes: 20 * _gib,
            ),
            tier: ResourceTier.low,
            reason: ResourceDecisionReason.unknownResources,
          ),
          (
            name: 'low-RAM flag takes precedence over otherwise high capacity',
            resources: DeviceResources(
              isLowRamDevice: true,
              totalMemoryBytes: 12 * _gib,
              memoryClassMb: 512,
              logicalProcessors: 8,
            ),
            tier: ResourceTier.low,
            reason: ResourceDecisionReason.lowRamDevice,
          ),
          (
            name: 'low total RAM includes exactly 3 GiB',
            resources: DeviceResources(
              totalMemoryBytes: 3 * _gib,
              memoryClassMb: 512,
              logicalProcessors: 8,
            ),
            tier: ResourceTier.low,
            reason: ResourceDecisionReason.lowTotalMemory,
          ),
          (
            name: 'one byte above low RAM threshold can be balanced',
            resources: DeviceResources(totalMemoryBytes: 3 * _gib + 1),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'low heap includes exactly 256 MB despite large physical RAM',
            resources: DeviceResources(
              totalMemoryBytes: 12 * _gib,
              memoryClassMb: 256,
              logicalProcessors: 8,
            ),
            tier: ResourceTier.low,
            reason: ResourceDecisionReason.lowMemoryClass,
          ),
          (
            name: 'heap just above low threshold can be balanced',
            resources: DeviceResources(memoryClassMb: 257),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'four CPUs without memory measurements use low fallback',
            resources: DeviceResources(logicalProcessors: 4),
            tier: ResourceTier.low,
            reason: ResourceDecisionReason.lowProcessorFallback,
          ),
          (
            name: 'five CPUs without memory measurements are balanced',
            resources: DeviceResources(logicalProcessors: 5),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'many CPUs alone do not qualify for high',
            resources: DeviceResources(logicalProcessors: 16),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'known RAM prevents CPU-only low fallback',
            resources: DeviceResources(
              logicalProcessors: 2,
              totalMemoryBytes: 4 * _gib,
            ),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'known heap prevents CPU-only low fallback',
            resources: DeviceResources(
              logicalProcessors: 2,
              memoryClassMb: 512,
            ),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'high starts at 6 GiB, six CPUs, and heap class 384',
            resources: DeviceResources(
              totalMemoryBytes: 6 * _gib,
              logicalProcessors: 6,
              memoryClassMb: 384,
            ),
            tier: ResourceTier.high,
            reason: ResourceDecisionReason.highCapacity,
          ),
          (
            name: 'unknown heap does not exclude measured high RAM and CPU',
            resources: DeviceResources(
              totalMemoryBytes: 6 * _gib,
              logicalProcessors: 6,
            ),
            tier: ResourceTier.high,
            reason: ResourceDecisionReason.highCapacity,
          ),
          (
            name: 'one byte below high RAM threshold stays balanced',
            resources: DeviceResources(
              totalMemoryBytes: 6 * _gib - 1,
              logicalProcessors: 6,
              memoryClassMb: 384,
            ),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'heap class below high threshold excludes high',
            resources: DeviceResources(
              totalMemoryBytes: 6 * _gib,
              logicalProcessors: 6,
              memoryClassMb: 383,
            ),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'five CPUs exclude high even with enough RAM and heap',
            resources: DeviceResources(
              totalMemoryBytes: 6 * _gib,
              logicalProcessors: 5,
              memoryClassMb: 384,
            ),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'missing CPU excludes high',
            resources: DeviceResources(
              totalMemoryBytes: 12 * _gib,
              memoryClassMb: 512,
            ),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'missing RAM excludes high',
            resources: DeviceResources(
              logicalProcessors: 8,
              memoryClassMb: 512,
            ),
            tier: ResourceTier.balanced,
            reason: ResourceDecisionReason.balancedCapacity,
          ),
          (
            name: 'reason reports low RAM before low heap',
            resources: DeviceResources(
              totalMemoryBytes: 2 * _gib,
              memoryClassMb: 128,
              logicalProcessors: 2,
            ),
            tier: ResourceTier.low,
            reason: ResourceDecisionReason.lowTotalMemory,
          ),
          (
            name: 'reason reports platform low-RAM flag before measured RAM',
            resources: DeviceResources(
              isLowRamDevice: true,
              totalMemoryBytes: 2 * _gib,
              memoryClassMb: 128,
            ),
            tier: ResourceTier.low,
            reason: ResourceDecisionReason.lowRamDevice,
          ),
        ];

    for (final scenario in cases) {
      test(scenario.name, () {
        final result = policy.evaluate(scenario.resources);
        expect(result.tier, scenario.tier);
        expect(result.reason, scenario.reason);
        expect(result.reduceEffects, scenario.tier == ResourceTier.low);
        expect(result.resources, same(scenario.resources));
      });
    }
  });

  test('default budgets use documented binary byte counts', () {
    final expected = [
      (const DeviceResources.unknown(), [20, 60, 2, 20, 60, 60, 24]),
      (
        DeviceResources(totalMemoryBytes: 4 * _gib),
        [36, 90, 4, 50, 120, 100, 40],
      ),
      (
        DeviceResources(totalMemoryBytes: 8 * _gib, logicalProcessors: 8),
        [48, 120, 5, 80, 180, 160, 60],
      ),
    ];
    for (final (resources, values) in expected) {
      final budgets = policy.evaluate(resources).budgets;
      expect(budgets.imageCacheBytes, values[0] * _mib);
      expect(budgets.imageCacheEntries, values[1]);
      expect(budgets.videoControllerLimit, values[2]);
      expect(budgets.httpCacheBytes, values[3] * _mib);
      expect(budgets.videoCacheBytes, values[4] * _mib);
      expect(budgets.chatCacheBytes, values[5] * _mib);
      expect(budgets.fileCacheBytes, values[6] * _mib);
    }
  });

  group('storage constraints', () {
    for (final storage in <int?>[null, 0, _gib - 1, _gib, _gib + 1]) {
      test('available storage $storage has an exclusive threshold', () {
        final resources = DeviceResources(
          logicalProcessors: 8,
          totalMemoryBytes: 8 * _gib,
          availableStorageBytes: storage,
        );
        final result = policy.evaluate(resources);
        final constrained = storage != null && storage < _gib;
        expect(result.isStorageConstrained, constrained);
        expect(result.tier, ResourceTier.high);
        expect(result.reason, ResourceDecisionReason.highCapacity);
        expect(result.reduceEffects, isFalse);
        expect(result.budgets.imageCacheBytes, 48 * _mib);
        expect(result.budgets.imageCacheEntries, 120);
        expect(result.budgets.videoControllerLimit, 5);
        expect(result.budgets.httpCacheBytes, (constrained ? 10 : 80) * _mib);
        expect(result.budgets.videoCacheBytes, (constrained ? 30 : 180) * _mib);
        expect(result.budgets.chatCacheBytes, (constrained ? 30 : 160) * _mib);
        expect(result.budgets.fileCacheBytes, (constrained ? 15 : 60) * _mib);
      });
    }

    test('caps never increase custom budgets, including disabled caches', () {
      final base = ResourceBudgets(
        imageCacheBytes: 7,
        imageCacheEntries: 3,
        videoControllerLimit: 1,
        httpCacheBytes: 0,
        videoCacheBytes: 2 * _mib,
        chatCacheBytes: 30 * _mib,
        fileCacheBytes: 20 * _mib,
      );
      final custom = ResourcePolicy(
        lowBudgets: base,
        balancedBudgets: base,
        highBudgets: base,
      );
      for (final ram in [2, 4, 8]) {
        final result = custom.evaluate(
          DeviceResources(
            totalMemoryBytes: ram * _gib,
            logicalProcessors: 8,
            availableStorageBytes: 0,
          ),
        );
        expect(result.budgets.imageCacheBytes, 7);
        expect(result.budgets.imageCacheEntries, 3);
        expect(result.budgets.videoControllerLimit, 1);
        expect(result.budgets.httpCacheBytes, 0);
        expect(result.budgets.videoCacheBytes, 2 * _mib);
        expect(result.budgets.chatCacheBytes, 30 * _mib);
        expect(result.budgets.fileCacheBytes, 15 * _mib);
      }
      expect(base.fileCacheBytes, 20 * _mib);
    });

    test(
      'custom caps can disable all disk caches without changing RAM budgets',
      () {
        final custom = ResourcePolicy(
          constrainedHttpCacheBytes: 0,
          constrainedVideoCacheBytes: 0,
          constrainedChatCacheBytes: 0,
          constrainedFileCacheBytes: 0,
        );
        final result = custom.evaluate(
          DeviceResources(availableStorageBytes: 0),
        );
        expect(result.budgets.httpCacheBytes, 0);
        expect(result.budgets.videoCacheBytes, 0);
        expect(result.budgets.chatCacheBytes, 0);
        expect(result.budgets.fileCacheBytes, 0);
        expect(result.budgets.imageCacheBytes, 20 * _mib);
      },
    );

    test(
      'zero storage threshold disables constraints even on a full volume',
      () {
        final custom = ResourcePolicy(
          thresholds: ResourceThresholds(constrainedStorageBelowBytes: 0),
        );
        final result = custom.evaluate(
          DeviceResources(availableStorageBytes: 0),
        );
        expect(result.isStorageConstrained, isFalse);
        expect(result.budgets, ResourceBudgets.lowDefaults);
      },
    );
  });

  test('all configured thresholds participate in decisions', () {
    final custom = ResourcePolicy(
      thresholds: ResourceThresholds(
        lowTotalMemoryMaxBytes: 2 * _gib,
        highTotalMemoryMinBytes: 4 * _gib,
        lowMemoryClassMaxMb: 128,
        highMemoryClassMinMb: 256,
        fallbackLowProcessorMax: 2,
        highProcessorMin: 4,
        constrainedStorageBelowBytes: 512 * _mib,
      ),
    );
    expect(
      custom.evaluate(DeviceResources(totalMemoryBytes: 3 * _gib)).tier,
      ResourceTier.balanced,
    );
    expect(
      custom.evaluate(DeviceResources(totalMemoryBytes: 2 * _gib)).reason,
      ResourceDecisionReason.lowTotalMemory,
    );
    expect(
      custom.evaluate(DeviceResources(memoryClassMb: 128)).reason,
      ResourceDecisionReason.lowMemoryClass,
    );
    expect(
      custom.evaluate(DeviceResources(memoryClassMb: 256)).tier,
      ResourceTier.balanced,
    );
    expect(
      custom.evaluate(DeviceResources(logicalProcessors: 2)).reason,
      ResourceDecisionReason.lowProcessorFallback,
    );
    expect(
      custom.evaluate(DeviceResources(logicalProcessors: 3)).tier,
      ResourceTier.balanced,
    );
    final high = custom.evaluate(
      DeviceResources(
        totalMemoryBytes: 4 * _gib,
        memoryClassMb: 256,
        logicalProcessors: 4,
        availableStorageBytes: 512 * _mib,
      ),
    );
    expect(high.tier, ResourceTier.high);
    expect(high.isStorageConstrained, isFalse);
    expect(
      custom
          .evaluate(DeviceResources(availableStorageBytes: 512 * _mib - 1))
          .isStorageConstrained,
      isTrue,
    );
  });

  test(
    'CPU fallback and high thresholds can overlap in different contexts',
    () {
      final custom = ResourcePolicy(
        thresholds: ResourceThresholds(
          fallbackLowProcessorMax: 4,
          highProcessorMin: 4,
        ),
      );
      final unknownMemory = custom.evaluate(
        DeviceResources(logicalProcessors: 4),
      );
      final measuredMemory = custom.evaluate(
        DeviceResources(logicalProcessors: 4, totalMemoryBytes: 6 * _gib),
      );
      expect(unknownMemory.tier, ResourceTier.low);
      expect(unknownMemory.reason, ResourceDecisionReason.lowProcessorFallback);
      expect(measuredMemory.tier, ResourceTier.high);
      expect(measuredMemory.reason, ResourceDecisionReason.highCapacity);
    },
  );

  group('validation', () {
    test(
      'web rejects infinity in every numeric factory argument',
      () {
        // Dart compiled to JavaScript can classify infinity as an int. Invoke
        // factories dynamically to model this runtime boundary, not a VM cast.
        final invalidNumber = double.infinity;
        final invalidNumberError = invalidNumber is int
            ? throwsArgumentError
            : throwsA(isA<TypeError>());
        final cases =
            <
              ({
                Function factory,
                Map<Symbol, Object> defaults,
                List<Symbol> fields,
              })
            >[
              (
                factory: DeviceResources.new,
                defaults: <Symbol, Object>{},
                fields: [
                  #logicalProcessors,
                  #memoryClassMb,
                  #totalMemoryBytes,
                  #availableStorageBytes,
                ],
              ),
              (
                factory: ResourceBudgets.new,
                defaults: <Symbol, Object>{
                  #imageCacheBytes: 0,
                  #imageCacheEntries: 0,
                  #videoControllerLimit: 0,
                  #httpCacheBytes: 0,
                  #videoCacheBytes: 0,
                  #chatCacheBytes: 0,
                  #fileCacheBytes: 0,
                },
                fields: [
                  #imageCacheBytes,
                  #imageCacheEntries,
                  #videoControllerLimit,
                  #httpCacheBytes,
                  #videoCacheBytes,
                  #chatCacheBytes,
                  #fileCacheBytes,
                ],
              ),
              (
                factory: ResourceThresholds.new,
                defaults: <Symbol, Object>{},
                fields: [
                  #lowTotalMemoryMaxBytes,
                  #highTotalMemoryMinBytes,
                  #lowMemoryClassMaxMb,
                  #highMemoryClassMinMb,
                  #fallbackLowProcessorMax,
                  #highProcessorMin,
                  #constrainedStorageBelowBytes,
                ],
              ),
              (
                factory: ResourcePolicy.new,
                defaults: <Symbol, Object>{},
                fields: [
                  #constrainedHttpCacheBytes,
                  #constrainedVideoCacheBytes,
                  #constrainedChatCacheBytes,
                  #constrainedFileCacheBytes,
                ],
              ),
            ];
        for (final scenario in cases) {
          for (final field in scenario.fields) {
            expect(
              () => Function.apply(scenario.factory, const [], {
                ...scenario.defaults,
                field: invalidNumber,
              }),
              invalidNumberError,
              reason: '$field must reject non-finite values on the web',
            );
          }
        }
      },
      skip: !kIsWeb ? 'Exercises JavaScript number representation.' : false,
    );

    final invalidResources = <String, DeviceResources Function()>{
      'zero processors': () => DeviceResources(logicalProcessors: 0),
      'negative processors': () => DeviceResources(logicalProcessors: -1),
      'zero heap': () => DeviceResources(memoryClassMb: 0),
      'negative heap': () => DeviceResources(memoryClassMb: -1),
      'zero RAM': () => DeviceResources(totalMemoryBytes: 0),
      'negative RAM': () => DeviceResources(totalMemoryBytes: -1),
      'negative storage': () => DeviceResources(availableStorageBytes: -1),
    };
    for (final entry in invalidResources.entries) {
      test('rejects ${entry.key}', () {
        expect(entry.value, throwsArgumentError);
      });
    }

    final invalidThresholds = <String, ResourceThresholds Function()>{
      'zero low RAM threshold': () =>
          ResourceThresholds(lowTotalMemoryMaxBytes: 0),
      'negative high RAM threshold': () =>
          ResourceThresholds(highTotalMemoryMinBytes: -1),
      'zero low heap threshold': () =>
          ResourceThresholds(lowMemoryClassMaxMb: 0),
      'negative high heap threshold': () =>
          ResourceThresholds(highMemoryClassMinMb: -1),
      'zero fallback CPU threshold': () =>
          ResourceThresholds(fallbackLowProcessorMax: 0),
      'negative high CPU threshold': () =>
          ResourceThresholds(highProcessorMin: -1),
      'overlapping RAM thresholds': () =>
          ResourceThresholds(highTotalMemoryMinBytes: 3 * _gib),
      'overlapping heap thresholds': () =>
          ResourceThresholds(highMemoryClassMinMb: 256),
      'negative storage threshold': () =>
          ResourceThresholds(constrainedStorageBelowBytes: -1),
    };
    for (final entry in invalidThresholds.entries) {
      test('rejects ${entry.key}', () {
        expect(entry.value, throwsArgumentError);
      });
    }

    test('every budget is validated and zero is accepted', () {
      for (var index = 0; index < 7; index++) {
        final values = List<int>.filled(7, 0)..[index] = -1;
        expect(() => _budgets(values), throwsArgumentError);
      }
      expect(_budgets(List<int>.filled(7, 0)).imageCacheBytes, 0);
    });

    test('all storage caps reject negative values', () {
      expect(
        () => ResourcePolicy(constrainedHttpCacheBytes: -1),
        throwsArgumentError,
      );
      expect(
        () => ResourcePolicy(constrainedVideoCacheBytes: -1),
        throwsArgumentError,
      );
      expect(
        () => ResourcePolicy(constrainedChatCacheBytes: -1),
        throwsArgumentError,
      );
      expect(
        () => ResourcePolicy(constrainedFileCacheBytes: -1),
        throwsArgumentError,
      );
    });
  });

  group('value semantics', () {
    test('equivalent resource snapshots deduplicate in sets', () {
      final first = DeviceResources(
        logicalProcessors: 8,
        isLowRamDevice: false,
        memoryClassMb: 512,
        totalMemoryBytes: 8 * _gib,
        availableStorageBytes: 2 * _gib,
      );
      final second = DeviceResources(
        logicalProcessors: 8,
        isLowRamDevice: false,
        memoryClassMb: 512,
        totalMemoryBytes: 8 * _gib,
        availableStorageBytes: 2 * _gib,
      );
      expect({first, second}, hasLength(1));
      expect(DeviceResources(), const DeviceResources.unknown());
      expect(DeviceResources(isLowRamDevice: false), isNot(DeviceResources()));
      expect(
        DeviceResources(availableStorageBytes: 0),
        isNot(DeviceResources()),
      );
    });

    test('all budget dimensions affect equality', () {
      final first = _budgets(List<int>.filled(7, 10));
      final sameValues = _budgets(List<int>.filled(7, 10));
      expect({first, sameValues}, hasLength(1));
      for (var index = 0; index < 7; index++) {
        final changed = List<int>.filled(7, 10)..[index] = 11;
        expect(_budgets(changed), isNot(first));
      }
    });

    test('equivalent thresholds deduplicate in sets', () {
      expect({ResourceThresholds(), ResourceThresholds.defaults}, hasLength(1));
      expect(
        ResourceThresholds(constrainedStorageBelowBytes: 0),
        isNot(ResourceThresholds.defaults),
      );
    });

    test('repeated evaluation is stable and retains original observations', () {
      final observations = DeviceResources(availableStorageBytes: 0);
      final first = policy.evaluate(observations);
      final again = policy.evaluate(observations);
      expect({first, again}, hasLength(1));
      expect(first.resources, same(observations));
      expect(observations.totalMemoryBytes, isNull);
      expect(policy.lowBudgets, ResourceBudgets.lowDefaults);
      expect(first.budgets.httpCacheBytes, 10 * _mib);
      expect(policy.lowBudgets.httpCacheBytes, 20 * _mib);
    });

    test('profile equality preserves observation and decision differences', () {
      final unknown = policy.evaluate(const DeviceResources.unknown());
      final measuredLow = policy.evaluate(
        DeviceResources(totalMemoryBytes: 2 * _gib),
      );
      expect(unknown.tier, measuredLow.tier);
      expect(unknown, isNot(measuredLow));
      expect(
        policy.evaluate(DeviceResources(availableStorageBytes: 0)),
        isNot(unknown),
      );
    });
  });
}

ResourceBudgets _budgets(List<int> values) => ResourceBudgets(
  imageCacheBytes: values[0],
  imageCacheEntries: values[1],
  videoControllerLimit: values[2],
  httpCacheBytes: values[3],
  videoCacheBytes: values[4],
  chatCacheBytes: values[5],
  fileCacheBytes: values[6],
);
