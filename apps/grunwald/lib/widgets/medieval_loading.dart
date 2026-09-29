import 'package:flutter/material.dart';

import '../theme/medieval_theme.dart';

class MedievalLoading extends StatelessWidget {
  const MedievalLoading({super.key});

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/app_icon.png', width: 104, height: 104),
              const SizedBox(height: 18),
              const Text(
                'GRUNWALD 2026',
                style: TextStyle(
                  color: MedievalColors.goldBright,
                  fontSize: 30,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  color: MedievalColors.goldBright,
                  backgroundColor: MedievalColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
