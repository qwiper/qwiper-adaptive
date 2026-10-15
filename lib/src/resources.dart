/// A relative resource tier selected by [ResourcePolicy].
///
/// Tiers describe an application's policy, not a hardware benchmark score.
enum ResourceTier {
  /// Cautious budgets and reduced optional visual effects.
  low,

  /// Intermediate budgets when capacity is neither low nor demonstrably high.
  balanced,

  /// Larger budgets when measured capacity passes the high thresholds.
  high,
}

/// An immutable snapshot of the resource signals available to a policy.
///
/// `null` means unknown; unknown signals are never replaced with invented
/// measurements. RAM and storage values use bytes. [memoryClassMb] is Android's
/// normal Java/Dalvik heap class in megabytes as reported by `ActivityManager`;
/// it is not a limit on all memory used by a Flutter process.
final class DeviceResources {
  /// Creates a validated snapshot.
  ///
  /// Known processor counts, heap classes, and total memory must be finite and
  /// positive. Available storage must be finite and may be zero. Invalid values
  /// throw [ArgumentError] in every build mode, including release builds.
  factory DeviceResources({
    int? logicalProcessors,
    bool? isLowRamDevice,
    int? memoryClassMb,
    int? totalMemoryBytes,
    int? availableStorageBytes,
  }) {
    _requirePositiveIfKnown(logicalProcessors, 'logicalProcessors');
    _requirePositiveIfKnown(memoryClassMb, 'memoryClassMb');
    _requirePositiveIfKnown(totalMemoryBytes, 'totalMemoryBytes');
    if (availableStorageBytes != null) {
      _requireNonNegative(availableStorageBytes, 'availableStorageBytes');
    }
    return DeviceResources._(
      logicalProcessors: logicalProcessors,
      isLowRamDevice: isLowRamDevice,
      memoryClassMb: memoryClassMb,
      totalMemoryBytes: totalMemoryBytes,
      availableStorageBytes: availableStorageBytes,
    );
  }

  const DeviceResources._({
    this.logicalProcessors,
    this.isLowRamDevice,
    this.memoryClassMb,
    this.totalMemoryBytes,
    this.availableStorageBytes,
  });

  /// A snapshot without measurements, usable before asynchronous detection.
  const DeviceResources.unknown()
    : logicalProcessors = null,
      isLowRamDevice = null,
      memoryClassMb = null,
      totalMemoryBytes = null,
      availableStorageBytes = null;

  /// Number of logical processors reported by the platform, if known.
  final int? logicalProcessors;

  /// Android's low-RAM-device classification, if available.
  final bool? isLowRamDevice;

  /// Android's normal application heap class, if available.
  final int? memoryClassMb;

  /// Total memory reported by the source, in bytes; not currently free RAM.
  /// Android reports memory accessible to the kernel, excluding some reservations.
  final int? totalMemoryBytes;

  /// Available bytes on the filesystem used for application data, if known.
  final int? availableStorageBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceResources &&
          logicalProcessors == other.logicalProcessors &&
          isLowRamDevice == other.isLowRamDevice &&
          memoryClassMb == other.memoryClassMb &&
          totalMemoryBytes == other.totalMemoryBytes &&
          availableStorageBytes == other.availableStorageBytes;

  @override
  int get hashCode => Object.hash(
    logicalProcessors,
    isLowRamDevice,
    memoryClassMb,
    totalMemoryBytes,
    availableStorageBytes,
  );

  @override
  String toString() =>
      'DeviceResources(logicalProcessors: $logicalProcessors, '
      'isLowRamDevice: $isLowRamDevice, memoryClassMb: $memoryClassMb, '
      'totalMemoryBytes: $totalMemoryBytes, '
      'availableStorageBytes: $availableStorageBytes)';
}

/// Immutable recommendations for independently managed application resources.
///
/// These are budgets, not reservations or a guarantee against memory pressure.
/// A consumer must enforce each relevant budget. All byte counts are in bytes;
/// the defaults use binary mebibytes (1 MiB = 1,048,576 bytes). A zero budget
/// means that the corresponding optional resource should be disabled.
final class ResourceBudgets {
  /// Creates budgets, rejecting negative or non-finite values in all build modes.
  factory ResourceBudgets({
    required int imageCacheBytes,
    required int imageCacheEntries,
    required int videoControllerLimit,
    required int httpCacheBytes,
    required int videoCacheBytes,
    required int chatCacheBytes,
    required int fileCacheBytes,
  }) {
    _requireNonNegative(imageCacheBytes, 'imageCacheBytes');
    _requireNonNegative(imageCacheEntries, 'imageCacheEntries');
    _requireNonNegative(videoControllerLimit, 'videoControllerLimit');
    _requireNonNegative(httpCacheBytes, 'httpCacheBytes');
    _requireNonNegative(videoCacheBytes, 'videoCacheBytes');
    _requireNonNegative(chatCacheBytes, 'chatCacheBytes');
    _requireNonNegative(fileCacheBytes, 'fileCacheBytes');
    return ResourceBudgets._(
      imageCacheBytes: imageCacheBytes,
      imageCacheEntries: imageCacheEntries,
      videoControllerLimit: videoControllerLimit,
      httpCacheBytes: httpCacheBytes,
      videoCacheBytes: videoCacheBytes,
      chatCacheBytes: chatCacheBytes,
      fileCacheBytes: fileCacheBytes,
    );
  }

  const ResourceBudgets._({
    required this.imageCacheBytes,
    required this.imageCacheEntries,
    required this.videoControllerLimit,
    required this.httpCacheBytes,
    required this.videoCacheBytes,
    required this.chatCacheBytes,
    required this.fileCacheBytes,
  });

  /// Initial recommendations for the low tier.
  static const lowDefaults = ResourceBudgets._(
    imageCacheBytes: 20 * 1024 * 1024,
    imageCacheEntries: 60,
    videoControllerLimit: 2,
    httpCacheBytes: 20 * 1024 * 1024,
    videoCacheBytes: 60 * 1024 * 1024,
    chatCacheBytes: 60 * 1024 * 1024,
    fileCacheBytes: 24 * 1024 * 1024,
  );

  /// Initial recommendations for the balanced tier.
  static const balancedDefaults = ResourceBudgets._(
    imageCacheBytes: 36 * 1024 * 1024,
    imageCacheEntries: 90,
    videoControllerLimit: 4,
    httpCacheBytes: 50 * 1024 * 1024,
    videoCacheBytes: 120 * 1024 * 1024,
    chatCacheBytes: 100 * 1024 * 1024,
    fileCacheBytes: 40 * 1024 * 1024,
  );

  /// Initial recommendations for the high tier.
  static const highDefaults = ResourceBudgets._(
    imageCacheBytes: 48 * 1024 * 1024,
    imageCacheEntries: 120,
    videoControllerLimit: 5,
    httpCacheBytes: 80 * 1024 * 1024,
    videoCacheBytes: 180 * 1024 * 1024,
    chatCacheBytes: 160 * 1024 * 1024,
    fileCacheBytes: 60 * 1024 * 1024,
  );

  /// Maximum bytes of completed images retained by an image cache.
  final int imageCacheBytes;

  /// Maximum number of completed images retained by an image cache.
  final int imageCacheEntries;

  /// Recommended maximum number of simultaneously retained video controllers.
  final int videoControllerLimit;

  /// Recommended HTTP disk cache size in bytes.
  final int httpCacheBytes;

  /// Recommended video disk cache size in bytes.
  final int videoCacheBytes;

  /// Recommended chat attachment disk cache size in bytes.
  final int chatCacheBytes;

  /// Recommended miscellaneous file disk cache size in bytes.
  final int fileCacheBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceBudgets &&
          imageCacheBytes == other.imageCacheBytes &&
          imageCacheEntries == other.imageCacheEntries &&
          videoControllerLimit == other.videoControllerLimit &&
          httpCacheBytes == other.httpCacheBytes &&
          videoCacheBytes == other.videoCacheBytes &&
          chatCacheBytes == other.chatCacheBytes &&
          fileCacheBytes == other.fileCacheBytes;

  @override
  int get hashCode => Object.hash(
    imageCacheBytes,
    imageCacheEntries,
    videoControllerLimit,
    httpCacheBytes,
    videoCacheBytes,
    chatCacheBytes,
    fileCacheBytes,
  );

  @override
  String toString() =>
      'ResourceBudgets(imageCacheBytes: $imageCacheBytes, '
      'imageCacheEntries: $imageCacheEntries, '
      'videoControllerLimit: $videoControllerLimit, '
      'httpCacheBytes: $httpCacheBytes, videoCacheBytes: $videoCacheBytes, '
      'chatCacheBytes: $chatCacheBytes, fileCacheBytes: $fileCacheBytes)';
}

/// The first matching condition that selected a profile's tier.
///
/// Storage constraints are reported independently by
/// [ResourceProfile.isStorageConstrained] and never change this decision.
enum ResourceDecisionReason {
  /// The platform explicitly reports a low-RAM device.
  lowRamDevice,

  /// Total physical RAM is at or below the configured low threshold.
  lowTotalMemory,

  /// The normal application heap class is at or below the low threshold.
  lowMemoryClass,

  /// Both memory measurements are unknown and the processor count is low.
  lowProcessorFallback,

  /// RAM, heap class, and processor count are all unknown.
  unknownResources,

  /// RAM and processor requirements pass, and heap class does not exclude high.
  highCapacity,

  /// No low or high condition matches; this includes partial measurements.
  balancedCapacity,
}

/// A policy decision together with the exact observations that produced it.
final class ResourceProfile {
  /// Creates an immutable decision value.
  const ResourceProfile({
    required this.resources,
    required this.tier,
    required this.budgets,
    required this.reduceEffects,
    required this.isStorageConstrained,
    required this.reason,
  });

  /// Original observations; no values are inferred or filled in by the policy.
  final DeviceResources resources;

  /// The selected relative resource tier.
  final ResourceTier tier;

  /// Recommendations after any storage caps have been applied.
  final ResourceBudgets budgets;

  /// Whether consumers should replace expensive optional visual effects.
  final bool reduceEffects;

  /// Whether observed available storage is below the policy's threshold.
  final bool isStorageConstrained;

  /// The decisive tier-selection condition, independent of storage.
  final ResourceDecisionReason reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceProfile &&
          resources == other.resources &&
          tier == other.tier &&
          budgets == other.budgets &&
          reduceEffects == other.reduceEffects &&
          isStorageConstrained == other.isStorageConstrained &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(
    resources,
    tier,
    budgets,
    reduceEffects,
    isStorageConstrained,
    reason,
  );

  @override
  String toString() =>
      'ResourceProfile(tier: ${tier.name}, reason: ${reason.name}, '
      'reduceEffects: $reduceEffects, '
      'isStorageConstrained: $isStorageConstrained, '
      'resources: $resources, budgets: $budgets)';
}

void _requirePositiveIfKnown(int? value, String name) {
  // JavaScript's number representation can make infinity satisfy `is int`.
  if (value != null && (!value.isFinite || value <= 0)) {
    throw ArgumentError.value(
      value,
      name,
      'Must be finite and positive when known',
    );
  }
}

void _requireNonNegative(int value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and nonnegative');
  }
}
