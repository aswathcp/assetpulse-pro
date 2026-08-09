import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../pages/profile_page.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;

  const CustomAppBar({
    super.key,
    this.title = 'AssetPulse Pro',
    this.onNotificationTap,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          // Logo placeholder or Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hub, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
      actions: [
        // Network Status
        Container(
          margin: const EdgeInsets.only(right: 16),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success,
                blurRadius: 4,
                spreadRadius: 1,
              )
            ],
          ),
        ),
        
        // Notifications
        IconButton(
          onPressed: onNotificationTap,
          icon: Icon(Icons.notifications_outlined, color: Theme.of(context).colorScheme.onSurface),
        ),

        // Avatar
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
