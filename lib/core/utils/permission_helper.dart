import 'package:asset_pulse_pro/core/constants/app_roles.dart';

class PermissionHelper {
  /// Map roles to numeric levels for comparing authority.
  /// A higher number represents higher authority.
  static int getUserAuthorityLevel(String role) {
    if (role == AppRoles.developer) return 120;
    if (role == AppRoles.businessAdmin) return 110;
    if (role == AppRoles.plantAdmin) return 100;
    if (role == AppRoles.plantHod) return 90;
    if (role == AppRoles.unitAdmin || role == AppRoles.unitHod) return 80;
    if (role == AppRoles.manager) return 70;
    if (role == AppRoles.deputyManager) return 60;
    if (role == AppRoles.associateManager) return 50;
    if (role == AppRoles.assistantManager) return 40;
    if (role == AppRoles.electrician) return 30;
    if (role == AppRoles.auditor) return 20;
    if (role == AppRoles.guest) return 10;
    return 0;
  }

  /// Check if the current user is allowed to manage the target user's account
  /// (e.g. approve/reject registration, edit profile, toggle LOTO rights).
  static bool canManageUser(Map<String, dynamic> current, Map<String, dynamic> target) {
    final String myRole = current['role'] ?? AppRoles.guest;
    final String targetRole = target['role'] ?? AppRoles.guest;

    // Developer can manage any non-developer user
    if (myRole == AppRoles.developer) {
      return targetRole != AppRoles.developer;
    }

    // No non-developer can manage/modify a developer
    if (targetRole == AppRoles.developer) {
      return false;
    }

    final myLevel = getUserAuthorityLevel(myRole);
    final targetLevel = getUserAuthorityLevel(targetRole);

    // Lower level admin cannot manage equal or higher level users
    return myLevel > targetLevel;
  }

  /// Check if the current user has rights to modify or delete database items
  /// within a specific plant and unit.
  static bool canEditDatabaseItem({
    required String? userRole,
    required bool isAdmin,
    required String? userPlantId,
    required String? userUnitId,
    required String? itemPlantId,
    required String? itemUnitId,
  }) {
    if (userRole == AppRoles.developer) {
      return true;
    }

    // Plant HOD / Admin with admin rights can edit all data in their plant
    if ((userRole == AppRoles.plantHod || userRole == AppRoles.plantAdmin) && isAdmin) {
      return itemPlantId != null && itemPlantId == userPlantId;
    }

    // Unit HOD/Admin can edit only their unit data (doesn't explicitly require admin flag)
    if (userRole == AppRoles.unitHod || userRole == AppRoles.unitAdmin) {
      return itemPlantId != null && itemPlantId == userPlantId &&
             itemUnitId != null && itemUnitId == userUnitId;
    }

    // Manager, Deputy, Associate, or Assistant Manager with admin rights is similar to Unit HOD
    if ((userRole == AppRoles.manager ||
         userRole == AppRoles.deputyManager ||
         userRole == AppRoles.associateManager ||
         userRole == AppRoles.assistantManager) && isAdmin) {
      return itemPlantId != null && itemPlantId == userPlantId &&
             itemUnitId != null && itemUnitId == userUnitId;
    }

    return false;
  }
}
