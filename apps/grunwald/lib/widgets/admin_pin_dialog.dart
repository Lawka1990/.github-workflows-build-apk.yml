import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_controller.dart';
import '../theme/medieval_theme.dart';

Future<bool> requestAdminAccess(
  BuildContext context,
  AppController controller,
) async {
  if (controller.adminUnlocked) return true;
  final textController = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      String? error;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: MedievalColors.charcoal,
            title: const Text('Dostęp administratora'),
            content: TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              obscureText: true,
              obscuringCharacter: '•',
              enableSuggestions: false,
              autocorrect: false,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Kod administratora',
                errorText: error,
                prefixIcon: const Icon(Icons.shield),
              ),
              onSubmitted: (_) {
                if (controller.unlockAdmin(textController.text.trim())) {
                  Navigator.pop(context, true);
                } else {
                  setState(() => error = 'Nieprawidłowy kod');
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.unlockAdmin(textController.text.trim())) {
                    Navigator.pop(context, true);
                  } else {
                    setState(() => error = 'Nieprawidłowy kod');
                  }
                },
                child: const Text('Wejdź'),
              ),
            ],
          );
        },
      );
    },
  );
  textController.dispose();
  return result ?? false;
}
