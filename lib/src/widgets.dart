import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'resources.dart';

/// Makes an explicitly selected resource profile available to descendants.
///
/// Changing any part of the profile notifies dependent widgets. There is no
/// process-wide profile and nesting scopes does not affect sibling subtrees.
class AdaptiveResourceScope extends InheritedWidget {
  /// Provides [profile] to [child].
  const AdaptiveResourceScope({
    super.key,
    required this.profile,
    required super.child,
  });

  /// Policy result selected by the application.
  final ResourceProfile profile;

  /// Returns the nearest profile and subscribes to its changes, if present.
  static ResourceProfile? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AdaptiveResourceScope>()
      ?.profile;

  /// Returns the nearest profile or throws if the integration omitted a scope.
  static ResourceProfile of(BuildContext context) {
    final profile = maybeOf(context);
    if (profile == null) {
      throw FlutterError(
        'AdaptiveResourceScope.of() requires an AdaptiveResourceScope ancestor.',
      );
    }
    return profile;
  }

  @override
  bool updateShouldNotify(AdaptiveResourceScope oldWidget) =>
      profile != oldWidget.profile;
}

/// Omits an expensive backdrop effect when the selected policy reduces effects.
///
/// Pass [profile] explicitly or place this widget below [AdaptiveResourceScope].
/// Without either, the effect is omitted conservatively. This widget does not
/// clip the filter: wrap it in ClipRect or ClipRRect to bound the painted area.
class AdaptiveBackdropFilter extends StatelessWidget {
  /// Creates an adaptive backdrop. [child] is always preserved.
  const AdaptiveBackdropFilter({
    super.key,
    required this.filter,
    required this.child,
    this.profile,
    this.blendMode = BlendMode.srcOver,
    this.enabled = true,
  });

  /// Backdrop image filter to use when effects are enabled.
  final ImageFilter filter;

  /// Foreground content, also used when the effect is omitted.
  final Widget child;

  /// Explicit profile overriding the nearest scope, if supplied.
  final ResourceProfile? profile;

  /// Blend mode passed through to Flutter's BackdropFilter.
  final BlendMode blendMode;

  /// Whether the application wants an effect at all.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selected = profile ?? AdaptiveResourceScope.maybeOf(context);
    return BackdropFilter(
      enabled: enabled && selected != null && !selected.reduceEffects,
      filter: filter,
      blendMode: blendMode,
      child: child,
    );
  }
}

/// Applies only image-cache limits to the explicitly supplied cache.
///
/// Pass PaintingBinding.instance.imageCache to opt into changing Flutter's
/// global cache, or a separate ImageCache for isolation. Lowering a limit may
/// evict cached entries; it does not bound live images or total process memory.
/// Other resource budgets are recommendations for the host application.
void applyImageCacheBudgets(ResourceProfile profile, ImageCache cache) {
  cache.maximumSizeBytes = profile.budgets.imageCacheBytes;
  cache.maximumSize = profile.budgets.imageCacheEntries;
}
