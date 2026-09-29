import 'package:flutter/material.dart';

import 'medieval_bottom_nav.dart';
import 'medieval_header.dart';

class MedievalScaffold extends StatelessWidget {
  const MedievalScaffold({
    required this.title,
    required this.body,
    required this.currentIndex,
    required this.onTabChanged,
    super.key,
    this.onShieldTap,
    this.adminActive = false,
  });

  final String title;
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback? onShieldTap;
  final bool adminActive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/leather.jpg'),
            fit: BoxFit.cover,
            repeat: ImageRepeat.repeat,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              MedievalHeader(
                title: title,
                onShieldTap: onShieldTap,
                adminActive: adminActive,
              ),
              Expanded(child: body),
              MedievalBottomNav(
                currentIndex: currentIndex,
                onChanged: onTabChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
