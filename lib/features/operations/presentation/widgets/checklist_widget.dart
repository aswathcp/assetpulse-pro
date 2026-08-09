import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_container.dart';

class ChecklistWidget extends StatefulWidget {
  const ChecklistWidget({super.key});

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Verify Unit A Pressure Readings', 'completed': true},
    {'title': 'Inspect Hydraulic Pump P-204', 'completed': true},
    {'title': 'Check Coolant Levels - M-101', 'completed': false},
    {'title': 'Record Meter Readings - Main Panel', 'completed': false},
    {'title': 'Safety Walkthrough - Zone B', 'completed': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        GlassContainer(
          width: double.infinity,
          height: 350, // Fixed height for list
          borderRadius: 20,
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _tasks.length,
            separatorBuilder: (c, i) => Divider(color: Theme.of(context).dividerColor),
            itemBuilder: (context, index) {
              return _buildTaskItem(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    int completed = _tasks.where((t) => t['completed']).length;
    double progress = completed / _tasks.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Daily Checklist',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                height: 4,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Theme.of(context).disabledColor.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(int index) {
    bool isCompleted = _tasks[index]['completed'];
    return ListTile(
      onTap: () {
        setState(() {
          _tasks[index]['completed'] = !isCompleted;
        });
      },
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.success : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isCompleted ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        child: isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
      title: Text(
        _tasks[index]['title'],
        style: TextStyle(
          color: isCompleted ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5) : Theme.of(context).colorScheme.onSurface,
          decoration: isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: isCompleted
          ? const SizedBox()
          : Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 16),
    ).animate(target: isCompleted ? 0 : 1).shimmer(duration: 1.seconds);
  }
}
