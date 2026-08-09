class AppRoles {
  // Special / Developer / Administrative Roles (Internally set or Legacy)
  static const String developer = 'Developer';
  static const String businessAdmin = 'Admin';
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
}
