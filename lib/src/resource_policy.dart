import 'dart:math' as math;

import 'resources.dart';

/// Validated thresholds for a deterministic, coarse resource policy.
///
/// Low memory thresholds are inclusive; high memory thresholds are inclusive.
/// The storage threshold is exclusive. Values are heuristics intended to be
/// configured and validated against an application's actual workload.
final class ResourceThresholds {
  /// Creates thresholds validated in every build mode.
  ///
  /// All thresholds must be finite, and capacity thresholds must be positive.
  /// Each high memory threshold must exceed its corresponding low threshold.
  /// Processor thresholds are independent: fallback applies only without
  /// memory observations, while
  /// high requires measured RAM. [constrainedStorageBelowBytes] may be zero,
  /// which disables storage constraints for all valid observations.
  factory ResourceThresholds({
    int lowTotalMemoryMaxBytes = 3 * 1024 * 1024 * 1024,
    int highTotalMemoryMinBytes = 6 * 1024 * 1024 * 1024,
    int lowMemoryClassMaxMb = 256,
    int highMemoryClassMinMb = 384,
    int fallbackLowProcessorMax = 4,
    int highProcessorMin = 6,
    int constrainedStorageBelowBytes = 1024 * 1024 * 1024,
  }) {
    _requirePositive(lowTotalMemoryMaxBytes, 'lowTotalMemoryMaxBytes');
    _requirePositive(highTotalMemoryMinBytes, 'highTotalMemoryMinBytes');
    _requirePositive(lowMemoryClassMaxMb, 'lowMemoryClassMaxMb');
    _requirePositive(highMemoryClassMinMb, 'highMemoryClassMinMb');
    _requirePositive(fallbackLowProcessorMax, 'fallbackLowProcessorMax');
    _requirePositive(highProcessorMin, 'highProcessorMin');
    _requireGreater(
      highTotalMemoryMinBytes,
      lowTotalMemoryMaxBytes,
      'highTotalMemoryMinBytes',
      'lowTotalMemoryMaxBytes',
    );
    _requireGreater(
      highMemoryClassMinMb,
      lowMemoryClassMaxMb,
      'highMemoryClassMinMb',
      'lowMemoryClassMaxMb',
    );
    _requireNonNegative(
      constrainedStorageBelowBytes,
      'constrainedStorageBelowBytes',
    );
    return ResourceThresholds._(
      lowTotalMemoryMaxBytes: lowTotalMemoryMaxBytes,
      highTotalMemoryMinBytes: highTotalMemoryMinBytes,
      lowMemoryClassMaxMb: lowMemoryClassMaxMb,
      highMemoryClassMinMb: highMemoryClassMinMb,
      fallbackLowProcessorMax: fallbackLowProcessorMax,
      highProcessorMin: highProcessorMin,
      constrainedStorageBelowBytes: constrainedStorageBelowBytes,
    );
  }

  const ResourceThresholds._({
    required this.lowTotalMemoryMaxBytes,
    required this.highTotalMemoryMinBytes,
    required this.lowMemoryClassMaxMb,
    required this.highMemoryClassMinMb,
    required this.fallbackLowProcessorMax,
    required this.highProcessorMin,
    required this.constrainedStorageBelowBytes,
  });

  /// The initial policy thresholds, without allocating configuration values.
  static const defaults = ResourceThresholds._(
    lowTotalMemoryMaxBytes: 3 * 1024 * 1024 * 1024,
    highTotalMemoryMinBytes: 6 * 1024 * 1024 * 1024,
    lowMemoryClassMaxMb: 256,
    highMemoryClassMinMb: 384,
    fallbackLowProcessorMax: 4,
    highProcessorMin: 6,
    constrainedStorageBelowBytes: 1024 * 1024 * 1024,
  );

  /// Reported total RAM at or below this value selects the low tier.
  final int lowTotalMemoryMaxBytes;

  /// Reported total RAM must be at least this value to select the high tier.
  final int highTotalMemoryMinBytes;

  /// A heap class at or below this value selects the low tier.
  final int lowMemoryClassMaxMb;

  /// A known heap class must be at least this value to select the high tier.
  final int highMemoryClassMinMb;

  /// Low processor fallback when both RAM and heap class are unknown.
  final int fallbackLowProcessorMax;

  /// Processor count must be at least this value to select the high tier.
  final int highProcessorMin;

  /// Available storage below this value activates disk cache caps.
  final int constrainedStorageBelowBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceThresholds &&
          lowTotalMemoryMaxBytes == other.lowTotalMemoryMaxBytes &&
          highTotalMemoryMinBytes == other.highTotalMemoryMinBytes &&
          lowMemoryClassMaxMb == other.lowMemoryClassMaxMb &&
          highMemoryClassMinMb == other.highMemoryClassMinMb &&
          fallbackLowProcessorMax == other.fallbackLowProcessorMax &&
          highProcessorMin == other.highProcessorMin &&
          constrainedStorageBelowBytes == other.constrainedStorageBelowBytes;

  @override
  int get hashCode => Object.hash(
    lowTotalMemoryMaxBytes,
    highTotalMemoryMinBytes,
    lowMemoryClassMaxMb,
    highMemoryClassMinMb,
    fallbackLowProcessorMax,
    highProcessorMin,
    constrainedStorageBelowBytes,
  );
}

/// Pure, deterministic resource recommendations from one measured snapshot.
///
/// Evaluation performs no platform calls, allocations of external resources,
/// global mutations, or background monitoring. Applications decide when to
/// obtain observations and how to apply the resulting budgets.
final class ResourcePolicy {
  /// Creates a policy with application-configurable thresholds and budgets.
  ///
  /// Storage caps must be finite and nonnegative. They cap only disk budgets
  /// and can never increase a configured budget. Budgets need not increase
  /// between tiers; an application may intentionally keep a resource disabled
  /// in every tier.
  factory ResourcePolicy({
    ResourceThresholds thresholds = ResourceThresholds.defaults,
    ResourceBudgets lowBudgets = ResourceBudgets.lowDefaults,
    ResourceBudgets balancedBudgets = ResourceBudgets.balancedDefaults,
    ResourceBudgets highBudgets = ResourceBudgets.highDefaults,
    int constrainedHttpCacheBytes = 10 * 1024 * 1024,
    int constrainedVideoCacheBytes = 30 * 1024 * 1024,
    int constrainedChatCacheBytes = 30 * 1024 * 1024,
    int constrainedFileCacheBytes = 15 * 1024 * 1024,
  }) {
    _requireNonNegative(constrainedHttpCacheBytes, 'constrainedHttpCacheBytes');
    _requireNonNegative(
      constrainedVideoCacheBytes,
      'constrainedVideoCacheBytes',
    );
    _requireNonNegative(constrainedChatCacheBytes, 'constrainedChatCacheBytes');
    _requireNonNegative(constrainedFileCacheBytes, 'constrainedFileCacheBytes');
    return ResourcePolicy._(
      thresholds: thresholds,
      lowBudgets: lowBudgets,
      balancedBudgets: balancedBudgets,
      highBudgets: highBudgets,
      constrainedHttpCacheBytes: constrainedHttpCacheBytes,
      constrainedVideoCacheBytes: constrainedVideoCacheBytes,
      constrainedChatCacheBytes: constrainedChatCacheBytes,
      constrainedFileCacheBytes: constrainedFileCacheBytes,
    );
  }

  const ResourcePolicy._({
    required this.thresholds,
    required this.lowBudgets,
    required this.balancedBudgets,
    required this.highBudgets,
    required this.constrainedHttpCacheBytes,
    required this.constrainedVideoCacheBytes,
    required this.constrainedChatCacheBytes,
    required this.constrainedFileCacheBytes,
  });

  /// Immutable decision thresholds.
  final ResourceThresholds thresholds;

  /// Resource recommendations before storage caps for the low tier.
  final ResourceBudgets lowBudgets;

  /// Resource recommendations before storage caps for the balanced tier.
  final ResourceBudgets balancedBudgets;

  /// Resource recommendations before storage caps for the high tier.
  final ResourceBudgets highBudgets;

  /// HTTP disk cache cap when storage is constrained.
  final int constrainedHttpCacheBytes;

  /// Video disk cache cap when storage is constrained.
  final int constrainedVideoCacheBytes;

  /// Chat attachment disk cache cap when storage is constrained.
  final int constrainedChatCacheBytes;

  /// Miscellaneous file disk cache cap when storage is constrained.
  final int constrainedFileCacheBytes;

  /// Evaluates [resources] without changing the observations or policy.
  ///
  /// Ordered precedence is low-RAM flag, low total RAM, low heap class, low
  /// processor fallback, unknown capacity, high capacity, then balanced.
  /// Missing RAM or CPU prevents the high tier; an unknown heap class does not
  /// prevent high when measured RAM and CPU qualify. The fallback uses CPU
  /// only when both RAM and heap class are unknown. Effects are reduced only
  /// for the low tier. Storage is evaluated separately and never changes tier.
  ResourceProfile evaluate(DeviceResources resources) {
    final reason = _classify(resources);
    final tier = switch (reason) {
      ResourceDecisionReason.highCapacity => ResourceTier.high,
      ResourceDecisionReason.balancedCapacity => ResourceTier.balanced,
      _ => ResourceTier.low,
    };
    final baseBudgets = switch (tier) {
      ResourceTier.low => lowBudgets,
      ResourceTier.balanced => balancedBudgets,
      ResourceTier.high => highBudgets,
    };
    final storage = resources.availableStorageBytes;
    final isStorageConstrained =
        storage != null && storage < thresholds.constrainedStorageBelowBytes;
    final budgets = isStorageConstrained
        ? ResourceBudgets(
            imageCacheBytes: baseBudgets.imageCacheBytes,
            imageCacheEntries: baseBudgets.imageCacheEntries,
            videoControllerLimit: baseBudgets.videoControllerLimit,
            httpCacheBytes: math.min(
              baseBudgets.httpCacheBytes,
              constrainedHttpCacheBytes,
            ),
            videoCacheBytes: math.min(
              baseBudgets.videoCacheBytes,
              constrainedVideoCacheBytes,
            ),
            chatCacheBytes: math.min(
              baseBudgets.chatCacheBytes,
              constrainedChatCacheBytes,
            ),
            fileCacheBytes: math.min(
              baseBudgets.fileCacheBytes,
              constrainedFileCacheBytes,
            ),
          )
        : baseBudgets;
    return ResourceProfile(
      resources: resources,
      tier: tier,
      budgets: budgets,
      reduceEffects: tier == ResourceTier.low,
      isStorageConstrained: isStorageConstrained,
      reason: reason,
    );
  }

  ResourceDecisionReason _classify(DeviceResources resources) {
    final ram = resources.totalMemoryBytes;
    final heap = resources.memoryClassMb;
    final cpu = resources.logicalProcessors;
    if (resources.isLowRamDevice == true) {
      return ResourceDecisionReason.lowRamDevice;
    }
    if (ram != null && ram <= thresholds.lowTotalMemoryMaxBytes) {
      return ResourceDecisionReason.lowTotalMemory;
    }
    if (heap != null && heap <= thresholds.lowMemoryClassMaxMb) {
      return ResourceDecisionReason.lowMemoryClass;
    }
    if (ram == null && heap == null) {
      if (cpu == null) return ResourceDecisionReason.unknownResources;
      if (cpu <= thresholds.fallbackLowProcessorMax) {
        return ResourceDecisionReason.lowProcessorFallback;
      }
    }
    if (ram != null &&
        ram >= thresholds.highTotalMemoryMinBytes &&
        cpu != null &&
        cpu >= thresholds.highProcessorMin &&
        (heap == null || heap >= thresholds.highMemoryClassMinMb)) {
      return ResourceDecisionReason.highCapacity;
    }
    return ResourceDecisionReason.balancedCapacity;
  }
}

void _requirePositive(int value, String name) {
  // JavaScript's number representation can make infinity satisfy `is int`.
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'Must be finite and positive');
  }
}

void _requireNonNegative(int value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and nonnegative');
  }
}

void _requireGreater(int value, int lower, String name, String lowerName) {
  if (value <= lower) {
    throw ArgumentError.value(value, name, 'Must exceed $lowerName ($lower)');
  }
}
