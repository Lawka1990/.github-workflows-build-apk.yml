import 'package:flutter/material.dart';

import 'pages/home_shell.dart';
import 'state/app_controller.dart';
import 'theme/medieval_theme.dart';
import 'widgets/medieval_loading.dart';

class GrunwaldBootstrap extends StatefulWidget {
  const GrunwaldBootstrap({super.key});

  @override
  State<GrunwaldBootstrap> createState() => _GrunwaldBootstrapState();
}

class _GrunwaldBootstrapState extends State<GrunwaldBootstrap> {
  late final AppController _controller;
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    _initialization = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grunwald 2026',
      theme: MedievalTheme.theme,
      home: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const MedievalLoading();
          }
          if (snapshot.hasError) {
            return _StartupError(
              message: snapshot.error.toString(),
              onRetry: () => setState(() {
                _initialization = _controller.initialize(force: true);
              }),
            );
          }
          return HomeShell(controller: _controller);
        },
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/leather.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 54,
                  color: MedievalColors.redBright,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nie udało się uruchomić aplikacji',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MedievalColors.goldBright,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MedievalColors.parchmentLight,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Spróbuj ponownie'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
