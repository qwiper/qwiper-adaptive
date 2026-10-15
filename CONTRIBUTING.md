# Contributing

Keep measurement, policy and host integration separate. Do not introduce hidden
global state, network access or implicit cache changes. Document missing-data
semantics and units. Treat resource thresholds as application choices; changes
need reproducible evidence, not a single-device impression.

## Local checks

Use Flutter 3.44.0 / Dart 3.12.0 or a newer toolchain that passes all checks.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool example/lib example/test example/integration_test
flutter analyze --fatal-infos
flutter test --coverage
flutter test --platform chrome
dart compile exe tool/policy_release_smoke.dart -o /tmp/qwiper-policy-smoke
/tmp/qwiper-policy-smoke
cd example
flutter pub get
flutter test
flutter test --platform chrome
flutter build web --release --no-web-resources-cdn
flutter build apk --debug
cd android
./gradlew :qwiper_adaptive:testDebugUnitTest
```

The Android commands require a JDK and Android SDK. Native integration also
requires an emulator or device:

```sh
cd example
flutter test integration_test/plugin_integration_test.dart -d <android-device-id>
```

An Android compile or JVM unit-test pass does not substitute for execution of
the platform channel on an Android device. Keep those results separate in the
validation record. Check unknown-resource behavior on the web demo as well.

## Review expectations

Tests should protect behavior: threshold boundaries, invalid release inputs,
partial native observations, timeouts, custom budgets, scope notifications,
child-state preservation and explicit cache ownership. Avoid assertions about
source-text fragments when executable behavior can be tested.

Use dartdoc for public API. Changes to default thresholds or interpretation of
unknown values are externally observable and must be described in the changelog.

## Pull requests

- Create a dedicated branch from the default branch for each change.
- Keep each pull request focused on a single topic; separate refactors from
  behavior changes.
- Run the local checks above before opening the pull request and mention any
  check you could not run (for example, missing Android SDK or device).
- Describe what changed and why, and link the related issue when one exists.
- Update tests, dartdoc and the changelog when the change is externally
  observable.

## Before public release

- Run CI from a fresh checkout and review its actual results.
- Run the native integration test on representative Android devices.
- Review provenance, the MIT license, dependencies and the final packaged files.
- Configure a private security-reporting channel and identify a maintainer.
- Set real repository/homepage links only after the hosting repository exists.
- Run `dart pub publish --dry-run`, then review its file list and diagnostics.
- Record device benchmarks separately before claiming speed or memory gains.

Publication is a separate maintainer action; no command in CI publishes packages.
