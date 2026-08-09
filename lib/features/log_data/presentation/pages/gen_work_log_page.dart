import 'package:flutter/material.dart';
import '../../../../core/widgets/animated_gradient_background.dart';
import '../../../home/presentation/widgets/custom_app_bar.dart';

class GenWorkLogPage extends StatelessWidget {
  final bool showAppBar;
  const GenWorkLogPage({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedGradientBackground(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.engineering_outlined, size: 80, color: Theme.of(context).disabledColor),
            const SizedBox(height: 20),
            Text(
              'General Work Logging Coming Soon',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Track non-breakdown maintenance tasks here.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );

    if (showAppBar) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'General Work Log'),
        body: content,
      );
    } else {
      return content;
    }
  }
}
