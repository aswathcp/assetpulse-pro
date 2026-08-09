import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import '../../../assets/data/models/fault_log_model.dart';

class LogFaultPage extends StatefulWidget {
  final String? listFilter; // 'Pending', 'Resolved', or null (All)
  final bool showAppBar;

  const LogFaultPage({super.key, this.listFilter, this.showAppBar = true});

  @override
  State<LogFaultPage> createState() => _LogFaultPageState();
}

class _LogFaultPageState extends State<LogFaultPage> {
  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedGradientBackground(
      child: StreamBuilder<List<FaultLogModel>>(
        stream: FirestoreService().getAllFaultLogsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: PulseLoading(size: 40));
          }

          var logs = snapshot.data ?? [];

          // Apply Filter
          if (widget.listFilter == 'Pending') {
            logs = logs.where((l) => l.status != FaultStatus.resolved && l.status != FaultStatus.closed).toList();
          } else if (widget.listFilter == 'Resolved') {
            logs = logs.where((l) => l.status == FaultStatus.resolved || l.status == FaultStatus.closed).toList();
          }

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Theme.of(context).disabledColor),
                  const SizedBox(height: 16),
                  Text('No fault logs match the current filter.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _buildLogCard(context, log);
            },
          );
        },
      ),
    );

    if (widget.showAppBar) {
      return Scaffold(
        extendBodyBehindAppBar: false,
        appBar: const CustomAppBar(title: 'Log Fault Records'),
        body: content,
      );
    } else {
      return content;
    }
  }

  Widget _buildLogCard(BuildContext context, FaultLogModel log) {
    Color statusColor = AppColors.success;
    if (log.status == FaultStatus.open || log.status == FaultStatus.pending) statusColor = AppColors.error;
    if (log.status == FaultStatus.in_progress) statusColor = AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        width: double.infinity,
        height: null,
        borderRadius: 16,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                     children: [
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                         child: Text(log.shift.name.toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                       ),
                       const SizedBox(width: 8),
                       Text(
                         log.category.name.toUpperCase(),
                         style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                       ),
                     ],
                   ),
                  _buildStatusBadge(log.status, statusColor),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                log.cause,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Equipment: ${log.masterEquipmentId}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              if (log.isOdcApplicable) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.report, size: 14, color: log.isOdcClosed ? Colors.green : Colors.orange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'ODC: ${log.isOdcClosed ? "Closed" : "Pending"} - ${log.odc}',
                        style: TextStyle(color: log.isOdcClosed ? Colors.green : Colors.orange, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Theme.of(context).disabledColor),
                      const SizedBox(width: 4),
                      Text(
                        log.reportedAt.toString().split(' ')[0],
                        style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12),
                      ),
                    ],
                  ),
                  if (log.assignedEngineers.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.engineering, size: 14, color: Theme.of(context).disabledColor),
                        const SizedBox(width: 4),
                        Text(
                          '${log.assignedEngineers.length} Assigned',
                          style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12),
                        ),
                      ],
                    ),
                  if (log.downtimeMinutes != null)
                    Row(
                      children: [
                        Icon(Icons.timer, size: 14, color: Theme.of(context).disabledColor),
                        const SizedBox(width: 4),
                        Text(
                          '${log.downtimeMinutes}m',
                          style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(FaultStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.name.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
