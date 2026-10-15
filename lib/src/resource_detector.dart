import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'resources.dart';

/// An asynchronous source of resource observations, injectable for host probes.
///
/// Return a map using the Android channel field names, or null if unavailable.
/// Expected channel failures should use [PlatformException]. Unexpected errors
/// from a custom reader propagate, so programming errors are not hidden.
typedef ResourceReader = Future<Object?> Function();

/// Outcome of a single probe. No result implies continuous monitoring.
enum ResourceReadStatus {
  /// All five observations were present and valid.
  available,

  /// At least one valid observation was present, with other fields absent.
  partial,

  /// The current platform has no built-in probe.
  unsupported,

  /// The channel was unavailable, failed, or returned no observations.
  unavailable,

  /// The configured deadline expired. The native operation is not cancelled.
  timedOut,

  /// The payload or a known field had the wrong type or range.
  invalidData,
}

/// Observations and diagnostic status from a resource probe.
@immutable
class ResourceReading {
  /// Creates a reading with no raw platform error text or device identifiers.
  const ResourceReading({required this.resources, required this.status});

  /// Valid observations; missing or invalid fields remain unknown.
  final DeviceResources resources;

  /// Whether observations were measured, partial, or unavailable.
  final ResourceReadStatus status;
}

/// Reads an Android resource snapshot or returns explicit unknown observations.
///
/// No permissions, network calls, persistent storage or global state are used.
/// Supply [reader] to support another platform or a controlled experiment.
class ResourceDetector {
  /// Creates a detector. [timeout] must be strictly positive.
  factory ResourceDetector({
    ResourceReader? reader,
    Duration timeout = const Duration(seconds: 2),
  }) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive');
    }
    return ResourceDetector._(reader, timeout);
  }

  ResourceDetector._(this._reader, this._timeout);

  static const _channel = MethodChannel('com.qwiper.adaptive/resources');
  final ResourceReader? _reader;
  final Duration _timeout;

  /// Takes one snapshot without mutating any Flutter or application cache.
  ///
  /// Initialise the Flutter binding before using the built-in channel. A custom
  /// reader takes precedence over the built-in platform support check.
  Future<ResourceReading> read() async {
    if (_reader == null &&
        (kIsWeb || defaultTargetPlatform != TargetPlatform.android)) {
      return _unknown(ResourceReadStatus.unsupported);
    }
    try {
      final value =
          await (_reader?.call() ??
                  _channel.invokeMethod<Object?>('readResources'))
              .timeout(_timeout);
      return _decode(value);
    } on TimeoutException {
      return _unknown(ResourceReadStatus.timedOut);
    } on MissingPluginException {
      return _unknown(ResourceReadStatus.unavailable);
    } on PlatformException {
      return _unknown(ResourceReadStatus.unavailable);
    }
  }

  static ResourceReading _unknown(ResourceReadStatus status) => ResourceReading(
    resources: const DeviceResources.unknown(),
    status: status,
  );

  static ResourceReading _decode(Object? value) {
    if (value == null) return _unknown(ResourceReadStatus.unavailable);
    if (value is! Map<Object?, Object?>) {
      return _unknown(ResourceReadStatus.invalidData);
    }
    var invalid = false;
    var observed = 0;
    int? integer(String key, {bool zeroAllowed = false}) {
      final raw = value[key];
      if (raw == null) return null;
      // StandardMessageCodec returns integers as int, never numeric strings.
      if (raw is! int || !raw.isFinite || raw < (zeroAllowed ? 0 : 1)) {
        invalid = true;
        return null;
      }
      observed++;
      return raw;
    }

    final lowRamRaw = value['isLowRamDevice'];
    final bool? lowRam;
    if (lowRamRaw == null) {
      lowRam = null;
    } else if (lowRamRaw is bool) {
      lowRam = lowRamRaw;
      observed++;
    } else {
      lowRam = null;
      invalid = true;
    }
    final resources = DeviceResources(
      logicalProcessors: integer('logicalProcessors'),
      isLowRamDevice: lowRam,
      memoryClassMb: integer('memoryClassMb'),
      totalMemoryBytes: integer('totalMemoryBytes'),
      availableStorageBytes: integer(
        'availableStorageBytes',
        zeroAllowed: true,
      ),
    );
    return ResourceReading(
      resources: resources,
      status: invalid
          ? ResourceReadStatus.invalidData
          : observed == 5
          ? ResourceReadStatus.available
          : observed > 0
          ? ResourceReadStatus.partial
          : ResourceReadStatus.unavailable,
    );
  }
}
