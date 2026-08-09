import 'package:flutter/material.dart';
import 'package:asset_pulse_pro/features/assets/data/models/isolation_permit_model.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../../core/widgets/pulse_loading.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/hierarchy_service.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';
import 'isolation_permit_card.dart';

class ClearIsolationPage extends StatelessWidget {
  const ClearIsolationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final businessId = HierarchyService().currentBusinessId;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Clear Active Isolations'),
      body: AnimatedGradientBackground(
        child: StreamBuilder<List<IsolationPermitModel>>(
          stream: FirestoreService().getActiveIsolationsStream(businessId: businessId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: PulseLoading(size: 50));
            }

            final permits = snapshot.data ?? [];

            if (permits.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                    SizedBox(height: 20),
                    Text('No Active Isolations Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: permits.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: IsolationPermitCard(permit: permits[index], showActions: true),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
