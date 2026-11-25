import 'package:asset_pulse_pro/core/constants/app_roles.dart';
import 'package:asset_pulse_pro/core/services/hierarchy_service.dart';

/// Represents the evaluated permissions and plant/unit scope locks for a user.
class UserScope {
  final String role;
  final bool isAdmin;
  final String? assignedPlant;
  final String? assignedUnit;
  final String? assignedBusiness;

  final bool isPlantLocked;
  final bool isUnitLocked;
  final bool canSwitchPlants;
  final bool canSwitchUnits;

  const UserScope({
    required this.role,
    required this.isAdmin,
    this.assignedPlant,
    this.assignedUnit,
    this.assignedBusiness,
    required this.isPlantLocked,
    required this.isUnitLocked,
    required this.canSwitchPlants,
    required this.canSwitchUnits,
  });

  /// Returns the authorized plants for this user.
  /// If the user is plant-locked, ONLY their assigned plant is returned.
  List<String> getAvailablePlants([List<String>? providedAllPlants]) {
    final allPlants = providedAllPlants ?? HierarchyService().getPlants();
    if (isPlantLocked) {
      if (assignedPlant != null && assignedPlant!.isNotEmpty) {
        return allPlants.contains(assignedPlant)
            ? [assignedPlant!]
            : (allPlants.isNotEmpty ? [allPlants.first] : [assignedPlant!]);
      }
    }
    return allPlants;
  }

  /// Returns the authorized units for the given plant.
  /// If the user is unit-locked, ONLY their assigned unit is returned.
  List<String> getAvailableUnits([dynamic arg1, dynamic arg2]) {
    String? plantId;
    List<String>? providedUnits;

    if (arg1 is String?) {
      plantId = arg1;
      if (arg2 is List<String>) {
        providedUnits = arg2;
      }
    } else if (arg1 is List<String>) {
      providedUnits = arg1;
    }

    final allUnits = providedUnits ?? (plantId != null ? HierarchyService().getUnitsForPlant(plantId) : HierarchyService().getUnitsForPlant(assignedPlant ?? 'VISL'));
    if (isUnitLocked) {
      if (assignedUnit != null && assignedUnit!.isNotEmpty) {
        return allUnits.contains(assignedUnit)
            ? [assignedUnit!]
            : (allUnits.isNotEmpty ? [allUnits.first] : [assignedUnit!]);
      }
    }
    return allUnits;
  }

  /// Initial plant to select
  String? getInitialPlant([dynamic arg1, dynamic arg2]) {
    String? preferred;
    List<String> plants = [];
    if (arg1 is List<String>) {
      plants = arg1;
      if (arg2 is String?) preferred = arg2;
    } else if (arg1 is String?) {
      preferred = arg1;
      if (arg2 is List<String>) plants = arg2;
    }

    if (preferred != null && preferred.isNotEmpty && plants.contains(preferred)) {
      if (!isPlantLocked || preferred == assignedPlant) return preferred;
    }
    if (assignedPlant != null && assignedPlant!.isNotEmpty && plants.contains(assignedPlant)) {
      return assignedPlant;
    }
    return plants.isNotEmpty ? plants.first : null;
  }

  /// Initial unit to select
  String? getInitialUnit([dynamic arg1, dynamic arg2, dynamic arg3]) {
    String? preferred;
    List<String> units = [];
    for (final arg in [arg1, arg2, arg3]) {
      if (arg is List<String>) {
        units = arg;
      } else if (arg is String? && arg != null && arg.isNotEmpty) {
        preferred = arg;
      }
    }

    if (preferred != null && units.contains(preferred)) {
      if (!isUnitLocked || preferred == assignedUnit) return preferred;
    }
    if (assignedUnit != null && assignedUnit!.isNotEmpty && units.contains(assignedUnit)) {
      return assignedUnit;
    }
    return units.isNotEmpty ? units.first : null;
  }
}

class PermissionHelper {
  /// Map roles to numeric levels for comparing authority.
  /// A higher number represents higher authority.
  static int getUserAuthorityLevel(String role) {
    final r = AppRoles.normalizeRole(role);
    if (r == AppRoles.developer) return 120;
    if (r == AppRoles.businessAdmin) return 110;
    if (r == AppRoles.plantAdmin) return 100;
    if (r == AppRoles.plantHod) return 90;
    if (r == AppRoles.unitAdmin) return 80;
    if (r == AppRoles.unitHod) return 75;
    if (r == AppRoles.manager) return 70;
    if (r == AppRoles.deputyManager) return 60;
    if (r == AppRoles.associateManager) return 50;
    if (r == AppRoles.assistantManager) return 40;
    if (r == AppRoles.electrician) return 30;
    if (r == AppRoles.auditor) return 20;
    if (r == AppRoles.guest) return 10;
    return 0;
  }

  /// Whether the user has permission to edit/modify database values and master records.
  /// Rules:
  /// - Developer: Highest of all, view and edit everything
  /// - Business Admin: View and edit everything across all plants & units
  /// - Plant Admin: Edit records within plant
  /// - Unit Admin: Edit records within unit
  /// - Plant and Unit HOD: Can VIEW but CANNOT edit
  /// - Other roles: View/operational entry only, cannot modify database values
  static bool canEditDatabase(dynamic profileOrRole) {
    String role;
    if (profileOrRole is Map<String, dynamic>) {
      role = profileOrRole['role']?.toString() ?? AppRoles.guest;
    } else if (profileOrRole is String) {
      role = profileOrRole;
    } else {
      return false;
    }
    final r = AppRoles.normalizeRole(role);
    if (r == AppRoles.plantHod || r == AppRoles.unitHod || r == AppRoles.auditor || r == AppRoles.guest) {
      return false;
    }
    return r == AppRoles.developer ||
        r == AppRoles.businessAdmin ||
        r == AppRoles.plantAdmin ||
        r == AppRoles.unitAdmin;
  }

  /// Global resolver for a user's plant and unit access scope.
  /// Enforces global rules across all screens so low-level users can NEVER
  /// see or select all plants/units, and only privileged roles can switch scope.
  static UserScope resolveUserScope(Map<String, dynamic>? profile) {
    if (profile == null) {
      return const UserScope(
        role: AppRoles.guest,
        isAdmin: false,
        isPlantLocked: true,
        isUnitLocked: true,
        canSwitchPlants: false,
        canSwitchUnits: false,
      );
    }

    final String role = AppRoles.normalizeRole(profile['role']?.toString());
    final bool rawIsAdmin = profile['isAdmin'] == true;

    final rawPlant = profile['plantId']?.toString();
    final rawUnit = profile['unitId']?.toString();
    final rawBusiness = profile['businessId']?.toString();

    final String? cleanPlant = (rawPlant == null || rawPlant.isEmpty || rawPlant == 'Unknown') ? null : rawPlant;
    final String? cleanUnit = (rawUnit == null || rawUnit.isEmpty || rawUnit == 'Unknown') ? null : rawUnit;
    final String? cleanBusiness = (rawBusiness == null || rawBusiness.isEmpty || rawBusiness == 'Unknown') ? null : rawBusiness;

    // View-only roles (Plant HOD, Unit HOD, Auditor, Guest) cannot be admin even if flag is set
    final bool isViewOnly = AppRoles.isViewOnlyRole(role);
    final bool effectiveAdmin = !isViewOnly && (rawIsAdmin || AppRoles.isAdminRole(role));

    // 1. GLOBAL PRIVILEGED ACCESS:
    // Developer, Auditor, or Global Business Admin (Admin with no specific plant bound)
    final bool isDeveloper = role == AppRoles.developer;
    final bool isAuditor = role == AppRoles.auditor;
    final bool isGlobalAdmin = role == AppRoles.businessAdmin || (effectiveAdmin && cleanPlant == null);

    if (isDeveloper || isAuditor || isGlobalAdmin) {
      return UserScope(
        role: role,
        isAdmin: effectiveAdmin,
        assignedPlant: cleanPlant,
        assignedUnit: cleanUnit,
        assignedBusiness: cleanBusiness,
        isPlantLocked: false,
        isUnitLocked: false,
        canSwitchPlants: true,
        canSwitchUnits: true,
      );
    }

    // 2. PLANT-LEVEL SCOPE:
    // Plant Admin or Plant HOD (or an Admin tied to a specific plant without unit restriction)
    // Their plant is STRICTLY LOCKED to their assigned plant.
    // They can switch between units within their plant.
    final bool isPlantScope = role == AppRoles.plantAdmin ||
                              role == AppRoles.plantHod ||
                              (effectiveAdmin && cleanPlant != null && cleanUnit == null);

    if (isPlantScope) {
      return UserScope(
        role: role,
        isAdmin: effectiveAdmin,
        assignedPlant: cleanPlant,
        assignedUnit: cleanUnit,
        assignedBusiness: cleanBusiness,
        isPlantLocked: true,
        isUnitLocked: false,
        canSwitchPlants: false,
        canSwitchUnits: true,
      );
    }

    // 3. UNIT-LEVEL & LOW-LEVEL OPERATIONAL SCOPE:
    // Unit Admin, Unit HOD, Managers, Assistant Managers, Electricians, Guests, etc.
    // Both Plant AND Unit are STRICTLY LOCKED to their assigned plant and unit.
    // They CANNOT switch plants, and CANNOT switch units.
    return UserScope(
      role: role,
      isAdmin: effectiveAdmin,
      assignedPlant: cleanPlant,
      assignedUnit: cleanUnit,
      assignedBusiness: cleanBusiness,
      isPlantLocked: true,
      isUnitLocked: true,
      canSwitchPlants: false,
      canSwitchUnits: false,
    );
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
