# Qwiper Adaptive

Explicit resource policies and adaptive effects for Flutter.

Qwiper Adaptive turns an optional device-resource snapshot into configurable cache and media budgets. It includes a small Android probe and a backdrop widget that disables its effect on constrained profiles while preserving its child's state. The application decides when to read resources and which budgets to apply.

**Status:** version 0.1.0, initial release. Default thresholds are heuristics extracted from Qwiper, not benchmark results or a universal performance classification. See [validation](VALIDATION.md) for what was actually checked.

## What is included

- Immutable resource snapshots with explicit unknown values.
- A deterministic policy with configurable thresholds and per-tier budgets.
- Independent storage caps that never increase a host-configured budget.
- An Android probe with no permissions, network, identifiers or persistence.
- An injectable reader, bounded by a deadline with explicit outcome statuses.
- A scoped adaptive backdrop effect and an explicit image-cache integration function.
- An interactive demo, tests, and a [French technical paper](doc/qwiper-adaptive-technical-paper.fr.pdf) with [editable sources](doc/technical-paper.fr.md).

No HTTP cache, media player, storage cleaner, network-speed estimator, or automatic background monitor is included. Cache budgets are recommendations, not a process-memory limit or storage reservations.

## Requirements and platforms

Tested toolchain: Flutter 3.44.0 and Dart 3.12.0. These are the declared minimum versions; compatibility with older versions is not claimed.

| Capability | Android API 24+ | Web, iOS and desktop |
|---|---|---|
| Policy and widgets | Yes | Platform-independent Dart/Flutter code |
| Built-in resource probe | ActivityManager and StatFs | No; returns `unsupported` and unknown values |
| Custom injected reader | Yes | Yes |

Cross-platform policy support does not imply native hardware detection on every platform. The web demo exercises the conservative fallback. Consult the validation record for platforms actually compiled or executed.

## Installation

```sh
flutter pub add qwiper_adaptive
```

Or add the dependency directly:

```yaml
dependencies:
  qwiper_adaptive: ^0.1.0
```

No service account or Qwiper backend is needed. For local development, use a
path dependency pointing to your checkout instead.

## Read, decide, apply

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qwiper_adaptive/qwiper_adaptive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final reading = await ResourceDetector().read();
  final profile = ResourcePolicy().evaluate(reading.resources);

  // Optional and explicit: this changes Flutter's global image cache.
  applyImageCacheBudgets(profile, PaintingBinding.instance.imageCache);

  runApp(AdaptiveResourceScope(
    profile: profile,
    child: MaterialApp(home: Scaffold(body: ClipRect(
      child: AdaptiveBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: const SizedBox(width: 200, height: 120),
      ),
    ))),
  ));
}
```

`read()` is a one-off snapshot with a two-second default deadline. You can start the UI immediately with `const DeviceResources.unknown()` and replace its scope after detection. Handle the reading status if your UI needs to distinguish measured data from a fallback. Re-read only when useful to your workload; this package does not monitor hardware continuously. A timeout does not cancel a native operation already in progress.

`AdaptiveBackdropFilter` accepts an explicit `profile` overriding its scope. With no profile or scope, the filter is disabled conservatively. It keeps a stable `BackdropFilter` render object and child subtree; it does not clip its own painted area. Use `ClipRect`/`ClipRRect` as appropriate.

The image-cache helper requires an explicit `ImageCache` argument. It changes only entry and byte limits. Live images, textures, Dart objects, native allocations and players can use additional memory. The host must independently enforce disk and video-controller budgets.

## Configure the policy

```dart
final policy = ResourcePolicy(
  thresholds: ResourceThresholds(
    lowTotalMemoryMaxBytes: 2 * 1024 * 1024 * 1024,
    highTotalMemoryMinBytes: 8 * 1024 * 1024 * 1024,
    constrainedStorageBelowBytes: 512 * 1024 * 1024,
  ),
  highBudgets: ResourceBudgets(
    imageCacheBytes: 32 * 1024 * 1024,
    imageCacheEntries: 80,
    videoControllerLimit: 2,
    httpCacheBytes: 30 * 1024 * 1024,
    videoCacheBytes: 80 * 1024 * 1024,
    chatCacheBytes: 60 * 1024 * 1024,
    fileCacheBytes: 20 * 1024 * 1024,
  ),
);
final profile = policy.evaluate(DeviceResources(
  logicalProcessors: 8,
  totalMemoryBytes: 8 * 1024 * 1024 * 1024,
  memoryClassMb: 512,
));
```

Invalid measurements, negative budgets, and inconsistent thresholds throw `ArgumentError` in release builds too. Zero cache budgets are allowed. A zero storage threshold disables the storage constraint. Unknown observations remain `null`; they are never replaced by synthetic device specifications.

The default classification follows this order:

1. Android low-RAM flag, reported total RAM ≤3 GiB, or normal Android memory class ≤256 MB → `low`.
2. If both RAM and memory class are unknown, CPU count ≤4 → `low`; with no CPU information either → `low`.
3. Physical RAM ≥6 GiB, CPU count ≥6, and memory class ≥384 MB or unknown → `high`.
4. Otherwise → `balanced`.

`memoryClassMb` is Android's normal app memory class, not current free memory or a total Flutter-process limit. CPU count is not a processor-speed measurement. `reason` identifies the first matching rule. Known available storage below 1 GiB adds disk caps independently of the tier.

| Budget | low | balanced | high | Storage constraint cap |
|---|---:|---:|---:|---:|
| Image cache, MiB | 20 | 36 | 48 | Unchanged |
| Image cache entries | 60 | 90 | 120 | Unchanged |
| Prepared video controllers | 2 | 4 | 5 | Unchanged |
| HTTP cache, MiB | 20 | 50 | 80 | 10 |
| Video cache, MiB | 60 | 120 | 180 | 30 |
| Chat attachment cache, MiB | 60 | 100 | 160 | 30 |
| File cache, MiB | 24 | 40 | 60 | 15 |

1 MiB = 1,048,576 bytes. Each constrained disk budget is `min(configured budget, cap)`. A free-space snapshot is not a reservation: a host must still handle full disks, write failures and aggregate usage.

## Custom readers and failure semantics

```dart
final detector = ResourceDetector(reader: () async => <String, Object?>{
  'logicalProcessors': 4,
  'totalMemoryBytes': 2 * 1024 * 1024 * 1024,
  // Omitted fields are unknown.
});
```

A custom reader takes precedence over built-in platform support. Accepted numeric fields are positive `int` values, except available storage, which also accepts zero. Strings and fractional numbers are not coerced. Malformed fields become unknown, valid fields survive, and the status is `invalidData`.

Statuses: `available`, `partial`, `unsupported`, `unavailable`, `timedOut`, `invalidData`. Expected channel failures are converted to statuses without returning native diagnostic text. Unexpected exceptions from a custom reader propagate so that integration errors remain visible.

## Demo and verification

```sh
flutter pub get
flutter analyze
flutter test --coverage
cd example
flutter pub get
flutter test
flutter run -d chrome
# Or use an Android device with its SDK installed:
flutter run -d <android-device-id>
```

The demo labels synthetic profiles and actual probe outcomes separately. Only its visual effect is adapted; displayed budgets do not mutate global caches. See [CONTRIBUTING.md](CONTRIBUTING.md) for native, AOT, formatting and release checks.

## Authors

- [Issoufa ABDOU OUSMANE](https://github.com/issoufaao)
- [Abdoul Matinou MAMANE AMADOU](https://github.com/AbdoulMatinou)
- [Abdoul Kader BACHIR OUSSEINI](https://github.com/DERKARIOM)

## Documentation and provenance

- [Technical paper in French](doc/technical-paper.fr.md)
- [Validation record](VALIDATION.md)
- [Contribution guide](CONTRIBUTING.md)
- [Security reporting](SECURITY.md)
- [MIT license](LICENSE)

Derived from Qwiper's resource-profile and adaptive-backdrop implementation. The public package separates platform observations, immutable policy decisions and explicit host integration. It does not include Qwiper's application sources, private APIs, credentials, databases or Git history. See [NOTICE](NOTICE).
