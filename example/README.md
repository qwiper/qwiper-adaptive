# Qwiper Adaptive demo

A responsive Flutter demo with labelled synthetic profiles and an Android
resource-read button. It applies the policy only to the backdrop effect. Cache
budgets are displayed but not applied globally.

From this directory:

```sh
flutter pub get
flutter test
flutter run -d chrome
```

On Android, use `flutter run -d <device-id>` with an installed Android SDK.
On the web, the built-in probe returns `unsupported`; use the synthetic profiles
to explore the same policy without inventing measurements for your computer.

## Integration test

The native probe is exercised by an integration test that needs a connected
Android emulator or device:

```sh
flutter devices
flutter test integration_test/plugin_integration_test.dart -d <android-device-id>
```

A web or desktop run does not execute the Android platform channel. See
[CONTRIBUTING.md](../CONTRIBUTING.md) for the full list of checks.
