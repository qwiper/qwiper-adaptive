// Validate the pure Dart policy with assertions disabled in a native AOT build:
// dart compile exe tool/policy_release_smoke.dart -o /tmp/qwiper-policy-smoke
// /tmp/qwiper-policy-smoke
//
// This program deliberately imports no Flutter libraries and uses no asserts.
// Any failed check throws, producing a nonzero process exit status.
// Source imports keep this smoke check runnable without package resolution.
// ignore_for_file: avoid_relative_lib_imports

import '../lib/src/resource_policy.dart';
import '../lib/src/resources.dart';

void main() {
  var checks = 0;
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
    checks++;
  }

  void rejects(void Function() action, String description) {
    try {
      action();
    } on ArgumentError {
      checks++;
      return;
    }
    throw StateError('$description did not throw ArgumentError');
  }

  const mib = 1024 * 1024;
  const gib = 1024 * mib;
  final policy = ResourcePolicy();
  final unknown = policy.evaluate(const DeviceResources.unknown());
  check(unknown.tier == ResourceTier.low, 'Unknown capacity must be cautious');
  check(
    unknown.reason == ResourceDecisionReason.unknownResources,
    'Unknown capacity needs an accurate reason',
  );
  check(
    unknown.resources.totalMemoryBytes == null,
    'Unknown RAM must stay null',
  );
  check(unknown.reduceEffects, 'Low-tier optional effects must be reduced');

  final high = policy.evaluate(
    DeviceResources(
      logicalProcessors: 6,
      memoryClassMb: 384,
      totalMemoryBytes: 6 * gib,
      availableStorageBytes: gib,
    ),
  );
  check(high.tier == ResourceTier.high, 'Inclusive high thresholds must match');
  check(!high.isStorageConstrained, 'Storage threshold must be exclusive');
  check(high.budgets.imageCacheBytes == 48 * mib, 'High image budget changed');
  check(
    high.budgets.videoControllerLimit == 5,
    'High controller budget changed',
  );
  check(
    !high.reduceEffects,
    'High tier must retain requested optional effects',
  );

  final restrictedHeap = policy.evaluate(
    DeviceResources(
      logicalProcessors: 12,
      memoryClassMb: 256,
      totalMemoryBytes: 12 * gib,
    ),
  );
  check(
    restrictedHeap.tier == ResourceTier.low,
    'Low heap must override large RAM',
  );
  check(
    restrictedHeap.reason == ResourceDecisionReason.lowMemoryClass,
    'Low heap must have its own decision reason',
  );

  final fourCpuPolicy = ResourcePolicy(
    thresholds: ResourceThresholds(
      highProcessorMin: 4,
      fallbackLowProcessorMax: 4,
    ),
  );
  check(
    fourCpuPolicy.evaluate(DeviceResources(logicalProcessors: 4)).tier ==
        ResourceTier.low,
    'Four CPUs without memory observations must retain the low fallback',
  );
  check(
    fourCpuPolicy
            .evaluate(
              DeviceResources(logicalProcessors: 4, totalMemoryBytes: 6 * gib),
            )
            .tier ==
        ResourceTier.high,
    'Measured memory permits an independently configured high CPU threshold',
  );

  final smallBudgets = ResourceBudgets(
    imageCacheBytes: 7,
    imageCacheEntries: 2,
    videoControllerLimit: 1,
    httpCacheBytes: 0,
    videoCacheBytes: 2 * mib,
    chatCacheBytes: 3 * mib,
    fileCacheBytes: 4 * mib,
  );
  final constrained = ResourcePolicy(
    lowBudgets: smallBudgets,
  ).evaluate(DeviceResources(availableStorageBytes: 0));
  check(
    constrained.isStorageConstrained,
    'Zero available storage is meaningful',
  );
  check(
    constrained.budgets == smallBudgets,
    'Storage caps must never raise budgets',
  );
  check(
    constrained.resources.availableStorageBytes == 0,
    'The original storage measurement must survive',
  );

  rejects(() => DeviceResources(logicalProcessors: 0), 'Zero processors');
  rejects(() => DeviceResources(memoryClassMb: -1), 'Negative heap class');
  rejects(() => DeviceResources(totalMemoryBytes: 0), 'Zero total RAM');
  rejects(() => DeviceResources(availableStorageBytes: -1), 'Negative storage');
  rejects(
    () => ResourceBudgets(
      imageCacheBytes: -1,
      imageCacheEntries: 1,
      videoControllerLimit: 1,
      httpCacheBytes: 0,
      videoCacheBytes: 0,
      chatCacheBytes: 0,
      fileCacheBytes: 0,
    ),
    'Negative budget',
  );
  rejects(
    () => ResourceThresholds(highTotalMemoryMinBytes: 3 * gib),
    'Overlapping RAM thresholds',
  );
  rejects(
    () => ResourceThresholds(constrainedStorageBelowBytes: -1),
    'Negative storage threshold',
  );
  rejects(
    () => ResourcePolicy(constrainedVideoCacheBytes: -1),
    'Negative storage cap',
  );
  check(
    {ResourceThresholds.defaults, ResourceThresholds()}.length == 1,
    'Equivalent thresholds must have equal hashes',
  );
  check(
    {policy.evaluate(high.resources), high}.length == 1,
    'Repeated policy evaluation must be stable',
  );
  // ignore: avoid_print
  print('Pure Dart policy release smoke: $checks checks passed.');
}
