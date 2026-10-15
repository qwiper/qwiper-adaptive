import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qwiper_adaptive/qwiper_adaptive.dart';

void main() => runApp(const AdaptiveDemoApp());

/// Demonstrates explicit policies using labelled synthetic or measured inputs.
class AdaptiveDemoApp extends StatelessWidget {
  /// Creates the demo, with an optional detector for reproducible tests.
  const AdaptiveDemoApp({super.key, this.detector});

  /// Optional host resource reader.
  final ResourceDetector? detector;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Qwiper Adaptive',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff007c83)),
      scaffoldBackgroundColor: const Color(0xfff5f7f8),
      useMaterial3: true,
    ),
    home: _DemoPage(detector: detector ?? ResourceDetector()),
  );
}

class _DemoPage extends StatefulWidget {
  const _DemoPage({required this.detector});
  final ResourceDetector detector;
  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  static final _samples = <String, DeviceResources>{
    'Modeste': DeviceResources(
      logicalProcessors: 4,
      isLowRamDevice: true,
      memoryClassMb: 192,
      totalMemoryBytes: 2 * 1024 * 1024 * 1024,
      availableStorageBytes: 12 * 1024 * 1024 * 1024,
    ),
    'Équilibré': DeviceResources(
      logicalProcessors: 8,
      isLowRamDevice: false,
      memoryClassMb: 384,
      totalMemoryBytes: 4 * 1024 * 1024 * 1024,
      availableStorageBytes: 32 * 1024 * 1024 * 1024,
    ),
    'Élevé': DeviceResources(
      logicalProcessors: 8,
      isLowRamDevice: false,
      memoryClassMb: 512,
      totalMemoryBytes: 8 * 1024 * 1024 * 1024,
      availableStorageBytes: 64 * 1024 * 1024 * 1024,
    ),
    'Inconnu': const DeviceResources.unknown(),
  };
  final _policy = ResourcePolicy();
  String _selected = 'Équilibré';
  bool _lowStorage = false;
  bool _loading = false;
  bool _readFailed = false;
  ResourceReading? _reading;

  DeviceResources get _resources {
    final source = _reading?.resources ?? _samples[_selected]!;
    return _lowStorage && _reading == null
        ? DeviceResources(
            logicalProcessors: source.logicalProcessors,
            isLowRamDevice: source.isLowRamDevice,
            memoryClassMb: source.memoryClassMb,
            totalMemoryBytes: source.totalMemoryBytes,
            availableStorageBytes: 512 * 1024 * 1024,
          )
        : source;
  }

  Future<void> _measure() async {
    setState(() {
      _loading = true;
      _readFailed = false;
    });
    try {
      final reading = await widget.detector.read();
      if (!mounted) return;
      setState(() {
        _reading = reading;
        _lowStorage = false;
      });
    } catch (_) {
      // This UI boundary reports custom-reader failures without displaying or
      // logging their potentially private text. Keep the previous observations.
      if (mounted) setState(() => _readFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _policy.evaluate(_resources);
    return AdaptiveResourceScope(
      profile: profile,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QWIPER / OPEN SOURCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Color(0xff007c83),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Une interface qui connaît ses limites.',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Mesurer les ressources. Choisir une politique. Appliquer les budgets explicitement.',
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final controls = _panel('1. Les observations', [
                          const Text(
                            'Scénarios artificiels : ils illustrent la politique, sans mesurer les performances.',
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _samples.keys
                                .map(
                                  (name) => ChoiceChip(
                                    key: ValueKey('scenario-$name'),
                                    label: Text(name),
                                    selected:
                                        _reading == null && _selected == name,
                                    onSelected: _loading
                                        ? null
                                        : (_) => setState(() {
                                            _selected = name;
                                            _reading = null;
                                            _readFailed = false;
                                          }),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile.adaptive(
                            key: const ValueKey('low-storage'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Simuler un stockage presque plein',
                            ),
                            subtitle: const Text('512 Mio disponibles'),
                            value: _lowStorage,
                            onChanged: _reading != null || _loading
                                ? null
                                : (value) =>
                                      setState(() => _lowStorage = value),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            key: const ValueKey('read-device'),
                            onPressed: _loading ? null : _measure,
                            icon: const Icon(Icons.sensors),
                            label: Text(
                              _loading ? 'Lecture…' : 'Lire cet appareil',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _reading == null
                                ? 'Source : simulation'
                                : 'Source : sonde • ${_reading!.status.name}',
                            key: const ValueKey('source'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (_readFailed)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Lecture impossible. Réessayez ou choisissez une simulation.',
                                key: ValueKey('read-error'),
                              ),
                            ),
                          if (_reading?.status ==
                              ResourceReadStatus.unsupported)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'La sonde native est disponible sur Android. Ici les ressources sont inconnues et la politique reste prudente.',
                              ),
                            ),
                          const SizedBox(height: 20),
                          _metric(
                            'Processeurs logiques',
                            '${_resources.logicalProcessors ?? 'Inconnu'}',
                          ),
                          _metric(
                            'RAM déclarée',
                            _bytes(_resources.totalMemoryBytes),
                          ),
                          _metric(
                            'Classe mémoire Android',
                            _resources.memoryClassMb == null
                                ? 'Inconnue'
                                : '${_resources.memoryClassMb} MB',
                          ),
                          _metric(
                            'Stockage libre',
                            _bytes(_resources.availableStorageBytes),
                          ),
                        ]);
                        final result = _panel('2. La politique', [
                          Text(
                            'Profil ${profile.tier.name}',
                            key: const ValueKey('tier'),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text('Décision : ${profile.reason.name}'),
                          const SizedBox(height: 16),
                          _BackdropPreview(reduced: profile.reduceEffects),
                          const SizedBox(height: 20),
                          _metric(
                            'Cache images en mémoire',
                            _bytes(profile.budgets.imageCacheBytes),
                          ),
                          _metric(
                            'Entrées du cache images',
                            '${profile.budgets.imageCacheEntries}',
                          ),
                          _metric(
                            'Lecteurs vidéo préparés',
                            '${profile.budgets.videoControllerLimit}',
                          ),
                          _metric(
                            'Cache HTTP sur disque',
                            _bytes(profile.budgets.httpCacheBytes),
                          ),
                          _metric(
                            'Cache vidéo sur disque',
                            _bytes(profile.budgets.videoCacheBytes),
                          ),
                          _metric(
                            'Cache messages sur disque',
                            _bytes(profile.budgets.chatCacheBytes),
                          ),
                          _metric(
                            'Cache fichiers sur disque',
                            _bytes(profile.budgets.fileCacheBytes),
                          ),
                          if (profile.isStorageConstrained)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Les plafonds de stockage sont réduits. Le profil de capacité reste indépendant.',
                              ),
                            ),
                        ]);
                        if (constraints.maxWidth < 850) {
                          return Column(
                            children: [
                              controls,
                              const SizedBox(height: 20),
                              result,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: controls),
                            const SizedBox(width: 24),
                            Expanded(child: result),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '3. L’application garde le contrôle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Cette démonstration applique le profil au flou uniquement. Les budgets affichés sont des recommandations : aucun cache global ni lecteur vidéo n’est modifié. Une limite de cache images ne plafonne pas la mémoire totale du processus.',
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'v0.1.0 • Mesures ponctuelles • Aucun envoi de données • Aucun gain de performance revendiqué',
                      style: TextStyle(color: Color(0xff52636a)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(String title, List<Widget> children) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );

  Widget _metric(String name, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 20,
      runSpacing: 4,
      children: [
        Text(name),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  String _bytes(int? value) => value == null
      ? 'Inconnu'
      : value >= 1 * 1024 * 1024 * 1024
      ? '${(value / (1 * 1024 * 1024 * 1024)).toStringAsFixed(1)} Gio'
      : '${(value / (1 * 1024 * 1024)).toStringAsFixed(0)} Mio';
}

class _BackdropPreview extends StatelessWidget {
  const _BackdropPreview({required this.reduced});
  final bool reduced;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xff004d61),
                  Color(0xff00b4a5),
                  Color(0xffffd19a),
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment(-0.5, -0.5),
            child: Icon(Icons.hexagon, color: Color(0xffe5f7f2), size: 110),
          ),
          const Align(
            alignment: Alignment(0.8, 0.7),
            child: Icon(Icons.circle, color: Color(0xff154e67), size: 120),
          ),
          AdaptiveBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: const Color(0x55122d37),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: Text(
                reduced ? 'Effet omis' : 'Flou activé',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
