// auth_service.dart

enum AdminRole { superAdmin, admin, none }

class AuthService {
  // Super Admin credentials - full access
  static const String _superAdminUsername = 'superadmin';
  static const String _superAdminPassword = 'Gdgxiilm07#';

  // Admin credentials - limited access (scan only)
  static const String _adminUsername = 'admin';
  static const String _adminPassword = 'admin123';

  // Current logged in user's role
  static AdminRole _currentRole = AdminRole.none;

  static AdminRole get currentRole => _currentRole;

  static bool get isSuperAdmin => _currentRole == AdminRole.superAdmin;
  static bool get isAdmin => _currentRole == AdminRole.admin;
  static bool get isLoggedIn => _currentRole != AdminRole.none;

  /// Returns the role if login is successful, otherwise returns AdminRole.none
  static AdminRole login(String username, String password) {
    if (username == _superAdminUsername && password == _superAdminPassword) {
      _currentRole = AdminRole.superAdmin;
      return AdminRole.superAdmin;
    } else if (username == _adminUsername && password == _adminPassword) {
      _currentRole = AdminRole.admin;
      return AdminRole.admin;
    }
    _currentRole = AdminRole.none;
    return AdminRole.none;
  }

  static void logout() {
    _currentRole = AdminRole.none;
  }
}
