import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class LogStreamWidget extends StatelessWidget {
  const LogStreamWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shift Log Stream',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _buildLogItem(
          context,
          '14:30',
          'Breakdown Reported',
          'Motor M-101 stopped unexpectedly. Maintenance team notified.',
          AppColors.error,
        ),
        _buildLogItem(
          context,
          '12:15',
          'Routine Inspection',
          'Unit B visual inspection completed. No issues found.',
          AppColors.success,
        ),
        _buildLogItem(
          context,
          '09:00',
          'Shift Started',
          'Shift A handed over. All systems green.',
          AppColors.info,
        ),
      ],
    );
  }

  Widget _buildLogItem(BuildContext context, String time, String title, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 50,
            child: Text(
              time,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
            ),
          ),
          
          // Timeline Line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).dividerColor, width: 2),
                ),
              ),
              Container(
                width: 2,
                height: 40, // Height of line connector
                color: Theme.of(context).dividerColor,
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
