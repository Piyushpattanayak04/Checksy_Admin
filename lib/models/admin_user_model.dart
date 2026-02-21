import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin User Model
/// Represents an admin user with organization association
class AdminUser {
  final String uid;
  final String email;
  final String? name;
  final String organizationId;
  final String organizationName;
  final AdminRole role;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  AdminUser({
    required this.uid,
    required this.email,
    this.name,
    required this.organizationId,
    required this.organizationName,
    this.role = AdminRole.orgAdmin,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });

  /// Create AdminUser from Firestore document
  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminUser.fromMap(doc.id, data);
  }

  /// Create AdminUser from Map
  factory AdminUser.fromMap(String uid, Map<String, dynamic> data) {
    return AdminUser(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'],
      organizationId: data['organizationId'] ?? '',
      organizationName: data['organizationName'] ?? '',
      role: AdminRole.fromString(data['role'] ?? 'org_admin'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'role': role.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
    };
  }

  /// Copy with modified fields
  AdminUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? organizationId,
    String? organizationName,
    AdminRole? role,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return AdminUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Check if admin can manage a specific organization
  bool canManageOrganization(String orgId) {
    if (role == AdminRole.superAdmin) return true;
    return organizationId == orgId;
  }

  /// Check if admin can create events
  bool get canCreateEvents => role == AdminRole.superAdmin || role == AdminRole.orgAdmin;

  /// Check if admin can delete events
  bool get canDeleteEvents => role == AdminRole.superAdmin || role == AdminRole.orgAdmin;

  /// Check if admin can scan QR codes
  bool get canScanQR => true; // All admins can scan

  /// Get display name (name or email)
  String get displayName => name?.isNotEmpty == true ? name! : email;

  /// Get initials for avatar
  String get initials {
    if (name?.isNotEmpty == true) {
      final words = name!.split(' ');
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      }
      return name!.substring(0, name!.length >= 2 ? 2 : 1).toUpperCase();
    }
    return email.substring(0, 2).toUpperCase();
  }

  @override
  String toString() => 'AdminUser(uid: $uid, email: $email, org: $organizationName, role: ${role.displayName})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminUser && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}

/// Admin roles
enum AdminRole {
  superAdmin('super_admin', 'Super Admin'),
  orgAdmin('org_admin', 'Organization Admin'),
  scanner('scanner', 'Scanner'); // Can only scan QR codes

  final String value;
  final String displayName;

  const AdminRole(this.value, this.displayName);

  static AdminRole fromString(String value) {
    return AdminRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AdminRole.scanner,
    );
  }
}
