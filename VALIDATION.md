# Validation record

Updated: 2026-10-16. Version: 0.1.0. Local checks below ran on 2026-10-15; remote CI evidence was reviewed on 2026-10-16. This is an execution record, not a certification.

Toolchain: Flutter 3.44.0 (`559ffa3f75e7402d65a8def9c28389a9b2e6fe42`), Dart 3.12.0, macOS 26.4.1. Browser tests use headless Chrome. The Android SDK is not installed on this machine.

## Executed checks

| Check | Result |
| --- | --- |
| Formatting and `flutter analyze --no-pub --fatal-infos` | Passed; no analyzer issues |
| Root `flutter test --no-pub --coverage` | 78 tests passed; 2 Web-specific cases skipped |
| Root `flutter test --platform chrome --no-pub` | 79 tests passed; 1 native Android channel case skipped |
| Example `flutter test --no-pub` | 7 tests passed |
| Example `flutter test --platform chrome --no-pub` | 7 tests passed |
| `dart compile exe tool/policy_release_smoke.dart` and execution | 26 checks passed with assertions disabled |
| Example `flutter build web --release --no-pub --no-web-resources-cdn` | Passed; final build includes both Material and Cupertino icon fonts |
| Browser inspection of the release build | Interface renders with the expected 4 GiB RAM / 32 GiB storage simulation; not a benchmark |
| PDF generation and rendered-page review | 8 pages; 3 editable SVG diagrams; all pages inspected, deterministic rebuild verified |
| Dart example extracted from the paper | Passed Flutter analysis with no issues |
| API documentation generation | 1 public library generated, 0 errors; 7 repository-relative link warnings until public hosting links are configured |
| Initial `dart pub publish --dry-run` | Archive reviewed; missing repository URL warning was addressed during release preparation |

The VM and browser checks are separate executions of substantially the same tests, not independent test counts. Platform-specific tests explicitly skip on the other runtime. Native channel simulations do not prove execution of Android APIs.

Tests cover threshold boundaries and priority, unknown and partial observations, invalid and non-finite inputs, configurable budgets, storage caps, timeouts, missing plugins, explicit cache ownership, scope notifications, child-state preservation, small-screen layout, text scaling pending-read interactions, recovery after reader failure and clearing simulated storage after a real read. Byte quantities use multiplication so large capacities survive JavaScript compilation.

## Remote CI evidence

[GitHub Actions run 38769174832](https://github.com/qwiper/qwiper-adaptive/actions/runs/38769174832), for commit `698472d1b6cab027b7df1516af3fd1d579a4389d`, completed successfully on 2026-10-15. Both jobs ran on fresh Ubuntu checkouts with the pinned Flutter SDK:

- `flutter`: formatting, analysis, VM/Chrome tests, AOT checks, example tests and the release Web build passed.
- `android`: the example debug APK compiled and all 12 Kotlin unit tests passed (7 collector and 5 plugin lifecycle/channel cases). The individual test results were checked in the job log.

The publication changes update metadata and documentation only; the tested Dart, Kotlin and Gradle sources are unchanged. JVM tests use mocks and do not exercise Android system APIs on a device.

## Not executed

- The Android integration test on a device or emulator.
- Physical-device performance, memory, thermal, energy or storage-load benchmarks.
- iOS, macOS, Windows and Linux application builds.

## Reproduce and qualify Android

From a fresh checkout, follow [CONTRIBUTING.md](CONTRIBUTING.md). The declared Android setup uses Java 17, Android SDK 36 and minimum API 24. Install the SDK/build tools and the NDK required by the pinned Flutter SDK through the normal Android toolchain setup.

```sh
cd example
flutter pub get
flutter build apk --debug
cd android
./gradlew :qwiper_adaptive:testDebugUnitTest
```

From `example/`, with an attached Android device or emulator:

```sh
flutter test integration_test/plugin_integration_test.dart -d <android-device-id>
```

Record the OS/API, device and actual results before release. Test representative constrained devices as well as higher-capacity hardware. A successful compile is not evidence of an operational native probe or of a performance improvement.

## Publication status

The public source repository is https://github.com/qwiper/qwiper-adaptive. Its URL and issue tracker are configured in `pubspec.yaml`. Release preparation targets `qwiper_adaptive` 0.1.0 on pub.dev; the registry page is the authoritative publication status. Keep the device and benchmark limitations above visible until they have been replaced by recorded execution evidence.

## Final independent review

The core, Android/CI, demo and technical paper were reviewed independently before
the initial commit. The demo now releases its loading state after an unexpected
custom-reader error, preserves prior observations on failure, and clears the
simulated-storage indicator after a completed read. Three regression tests cover
these transitions. The paper now specifies wire statuses, algorithm precedence,
units and independent profile consumers. Names in AUTHORS, README, NOTICE and
the paper identify the requested authors. This review does not replace native
Android execution or establish an absence of all possible defects.
