import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Chip colorido que representa o status de leitura de um livro.
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  Color get _color => switch (status) {
        'Lido' => AppColors.statusRead,
        'Lendo' => AppColors.statusReading,
        _ => AppColors.statusWantToRead,
      };

  IconData get _icon => switch (status) {
        'Lido' => Icons.check_circle_outline,
        'Lendo' => Icons.auto_stories,
        _ => Icons.bookmark_border,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}