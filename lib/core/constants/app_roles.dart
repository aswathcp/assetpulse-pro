class AppRoles {
  // Special / Developer / Administrative Roles
  static const String developer = 'Developer';
  static const String businessAdmin = 'Business Admin';
  static const String plantAdmin = 'Plant Admin';
  static const String unitAdmin = 'Unit Admin';

  // Standard Roles
  static const String plantHod = 'Plant HOD';
  static const String unitHod = 'Unit HOD';
  static const String manager = 'Manager';
  static const String deputyManager = 'Deputy Manager';
  static const String associateManager = 'Associate Manager';
  static const String assistantManager = 'Assistant Manager';
  static const String electrician = 'Electrician';
  static const String guest = 'Guest';
  static const String auditor = 'Auditor';

  // List of all roles for validation
  static const List<String> values = [
    developer,
    businessAdmin,
    plantAdmin,
    unitAdmin,
    plantHod,
    unitHod,
    manager,
    deputyManager,
    associateManager,
    assistantManager,
    electrician,
    guest,
    auditor,
  ];

  // List of roles available for new User Registration (excludes privileged roles)
  static const List<String> registrationRoles = [
    plantHod,
    unitHod,
    manager,
    deputyManager,
    associateManager,
    assistantManager,
    electrician,
    guest,
    auditor,
  ];

  /// Normalize legacy role strings if needed (e.g. legacy 'Admin' -> 'Business Admin')
  static String normalizeRole(String? role) {
    if (role == null || role.isEmpty) return guest;
    if (role.toLowerCase() == 'admin' || role == 'Business Admin') {
      return businessAdmin;
    }
    return role;
  }

  /// Whether the role possesses administrative authority
  static bool isAdminRole(String? role) {
    final r = normalizeRole(role);
    return r == developer ||
        r == businessAdmin ||
        r == plantAdmin ||
        r == unitAdmin;
  }

  /// Whether the role is strictly view-only (Plant HOD and Unit HOD can view but not edit)
  static bool isViewOnlyRole(String? role) {
    final r = normalizeRole(role);
    return r == plantHod || r == unitHod || r == auditor || r == guest;
  }
}
