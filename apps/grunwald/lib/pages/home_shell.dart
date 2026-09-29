import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../widgets/admin_pin_dialog.dart';
import '../widgets/medieval_scaffold.dart';
import 'map_page.dart';
import 'now_page.dart';
import 'places_page.dart';
import 'program_page.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  static const List<String> _titles = <String>['Mapa', 'Miejsca', 'Teraz', 'Program'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MedievalScaffold(
          title: _titles[controller.selectedTab],
          currentIndex: controller.selectedTab,
          onTabChanged: controller.selectTab,
          adminActive: controller.adminUnlocked,
          onShieldTap: () async {
            if (controller.adminUnlocked) {
              final shouldLock = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Administrator aktywny'),
                  content: const Text(
                    'Możesz edytować i kalibrować punkty na mapie.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Zostań w trybie admina'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.lock),
                      label: const Text('Wyłącz admina'),
                    ),
                  ],
                ),
              );
              if (shouldLock == true) controller.lockAdmin();
              return;
            }
            final unlocked = await requestAdminAccess(context, controller);
            if (unlocked && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tryb administratora jest aktywny.')),
              );
            }
          },
          body: IndexedStack(
            index: controller.selectedTab,
            children: [
              MapPage(controller: controller),
              PlacesPage(controller: controller),
              NowPage(controller: controller),
              ProgramPage(controller: controller),
            ],
          ),
        );
      },
    );
  }
}
