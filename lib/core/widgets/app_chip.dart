import 'package:flutter/material.dart';

/// Chip com alvo de toque ≥48dp (doc 15 §3).
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.rotulo, this.icone});

  final String rotulo;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          avatar: icone == null ? null : Icon(icone, size: 18),
          label: Text(rotulo),
        ),
      ),
    );
  }
}
