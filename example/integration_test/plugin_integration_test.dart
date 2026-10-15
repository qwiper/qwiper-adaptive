import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qwiper_adaptive/qwiper_adaptive.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Android probe returns measured resources', (
    tester,
  ) async {
    final reading = await ResourceDetector().read();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      expect(
        reading.status,
        anyOf(ResourceReadStatus.available, ResourceReadStatus.partial),
      );
      expect(reading.resources.logicalProcessors, greaterThan(0));
      expect(reading.resources.memoryClassMb, greaterThan(0));
      expect(reading.resources.totalMemoryBytes, greaterThan(0));
      expect(reading.resources.availableStorageBytes, greaterThanOrEqualTo(0));
    } else {
      expect(reading.status, ResourceReadStatus.unsupported);
      expect(reading.resources, const DeviceResources.unknown());
    }
  });
}
