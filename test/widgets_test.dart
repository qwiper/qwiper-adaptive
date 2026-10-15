import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qwiper_adaptive/qwiper_adaptive.dart';

void main() {
  final low = ResourcePolicy().evaluate(const DeviceResources.unknown());
  final high = ResourcePolicy().evaluate(
    DeviceResources(
      logicalProcessors: 8,
      totalMemoryBytes: 8 * 1024 * 1024 * 1024,
      memoryClassMb: 512,
    ),
  );
  Widget filtered({ResourceProfile? profile, bool enabled = true}) =>
      AdaptiveBackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        profile: profile,
        enabled: enabled,
        child: const SizedBox(key: ValueKey('content'), width: 30, height: 30),
      );

  testWidgets('missing profile omits effect and preserves content', (
    tester,
  ) async {
    await tester.pumpWidget(filtered());
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    expect(find.byKey(const ValueKey('content')), findsOneWidget);
  });

  testWidgets('scope changes toggle effects without replacing the child', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdaptiveResourceScope(profile: high, child: filtered()),
    );
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
    await tester.pumpWidget(
      AdaptiveResourceScope(profile: low, child: filtered()),
    );
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    expect(find.byKey(const ValueKey('content')), findsOneWidget);
  });

  testWidgets('explicit profile takes precedence over enclosing scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdaptiveResourceScope(
        profile: low,
        child: filtered(profile: high),
      ),
    );
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
  });

  testWidgets(
    'tier changes preserve child state and dispose it only on removal',
    (tester) async {
      var initializations = 0;
      var disposals = 0;
      final child = _StateProbe(
        key: const ValueKey('stateful-content'),
        onInitialize: () => initializations++,
        onDispose: () => disposals++,
      );
      Widget scoped(ResourceProfile profile) => AdaptiveResourceScope(
        profile: profile,
        child: AdaptiveBackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: child,
        ),
      );

      await tester.pumpWidget(scoped(high));
      final originalState = tester.state<_StateProbeState>(
        find.byType(_StateProbe),
      );
      await tester.pumpWidget(scoped(low));
      expect(tester.state(find.byType(_StateProbe)), same(originalState));
      await tester.pumpWidget(scoped(high));
      expect(tester.state(find.byType(_StateProbe)), same(originalState));
      expect(initializations, 1);
      expect(disposals, 0);
      await tester.pumpWidget(const SizedBox());
      expect(disposals, 1);
    },
  );

  testWidgets('host can disable effects even for a high profile', (
    tester,
  ) async {
    await tester.pumpWidget(filtered(profile: high, enabled: false));
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
  });

  testWidgets('same tier with changed budgets notifies consumers', (
    tester,
  ) async {
    final second = ResourcePolicy(
      highBudgets: ResourceBudgets(
        imageCacheBytes: 1024,
        imageCacheEntries: 3,
        videoControllerLimit: 1,
        httpCacheBytes: 1,
        videoCacheBytes: 2,
        chatCacheBytes: 3,
        fileCacheBytes: 4,
      ),
    ).evaluate(high.resources);
    var builds = 0;
    final child = Builder(
      builder: (context) {
        builds++;
        return Text(
          '${AdaptiveResourceScope.of(context).budgets.imageCacheBytes}',
          textDirection: TextDirection.ltr,
        );
      },
    );
    await tester.pumpWidget(AdaptiveResourceScope(profile: high, child: child));
    await tester.pumpWidget(
      AdaptiveResourceScope(profile: second, child: child),
    );
    expect(builds, 2);
    expect(find.text('1024'), findsOneWidget);
  });

  testWidgets('required scope lookup reports an actionable integration error', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          AdaptiveResourceScope.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(tester.takeException(), isA<FlutterError>());
  });

  test('cache application is explicit and affects only the supplied cache', () {
    final cache = ImageCache();
    final other = ImageCache();
    final originalBytes = other.maximumSizeBytes;
    final originalEntries = other.maximumSize;
    applyImageCacheBudgets(low, cache);
    expect(cache.maximumSizeBytes, low.budgets.imageCacheBytes);
    expect(cache.maximumSize, low.budgets.imageCacheEntries);
    expect(other.maximumSizeBytes, originalBytes);
    expect(other.maximumSize, originalEntries);
    cache.clear();
    other.clear();
  });
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({
    super.key,
    required this.onInitialize,
    required this.onDispose,
  });

  final VoidCallback onInitialize;
  final VoidCallback onDispose;

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInitialize();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 30, height: 30);
}
