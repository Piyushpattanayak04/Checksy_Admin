import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_user_model.dart';

/// Firebase-based Admin Authentication Service
/// Replaces hardcoded credentials with proper Firebase authentication
class AdminAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _adminUsersCollection = 'adminUsers';

  // Current logged in admin user
  static AdminUser? _currentAdmin;

  /// Get current admin user
  static AdminUser? get currentAdmin => _currentAdmin;

  /// Check if user is logged in
  static bool get isLoggedIn =>
      _currentAdmin != null && _auth.currentUser != null;

  /// Check if current user is super admin
  static bool get isSuperAdmin => _currentAdmin?.role == AdminRole.superAdmin;

  /// Check if current user is organization admin
  static bool get isOrgAdmin =>
      _currentAdmin?.role == AdminRole.orgAdmin ||
      _currentAdmin?.role == AdminRole.superAdmin;

  /// Get current organization ID
  static String? get currentOrganizationId => _currentAdmin?.organizationId;

  /// Get current organization name
  static String? get currentOrganizationName => _currentAdmin?.organizationName;

  /// Login with email and password
  /// Returns AdminUser on success, throws exception on failure
  static Future<AdminUser> login(String email, String password) async {
    try {
      // Authenticate with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Authentication failed');
      }

      // Fetch admin profile from Firestore
      final adminDoc =
          await _firestore
              .collection(_adminUsersCollection)
              .doc(user.uid)
              .get();

      if (!adminDoc.exists) {
        // User exists in Firebase Auth but not in adminUsers collection
        await _auth.signOut();
        throw Exception(
          'You are not registered as an admin. Please contact support.',
        );
      }

      final adminUser = AdminUser.fromFirestore(adminDoc);

      // Check if admin is active
      if (!adminUser.isActive) {
        await _auth.signOut();
        throw Exception('Your admin account has been deactivated.');
      }

      // Update last login time
      await _firestore.collection(_adminUsersCollection).doc(user.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      _currentAdmin = adminUser;
      return adminUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  /// Logout current user
  static Future<void> logout() async {
    await _auth.signOut();
    _currentAdmin = null;
  }

  /// Check if current Firebase user has admin profile and restore session
  static Future<AdminUser?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final adminDoc =
          await _firestore
              .collection(_adminUsersCollection)
              .doc(user.uid)
              .get();

      if (!adminDoc.exists) {
        await _auth.signOut();
        return null;
      }

      final adminUser = AdminUser.fromFirestore(adminDoc);

      if (!adminUser.isActive) {
        await _auth.signOut();
        return null;
      }

      _currentAdmin = adminUser;
      return adminUser;
    } catch (e) {
      print('Error restoring session: $e');
      await _auth.signOut();
      return null;
    }
  }

  /// Register a new admin (only super admins can do this)
  static Future<AdminUser> registerAdmin({
    required String email,
    required String password,
    required String organizationId,
    required String organizationName,
    String? name,
    AdminRole role = AdminRole.orgAdmin,
  }) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admins can register new admins');
    }

    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user');
      }

      // Create admin profile in Firestore
      final adminUser = AdminUser(
        uid: user.uid,
        email: email.trim(),
        name: name,
        organizationId: organizationId,
        organizationName: organizationName,
        role: role,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_adminUsersCollection)
          .doc(user.uid)
          .set(adminUser.toMap());

      return adminUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Update admin profile
  static Future<void> updateAdminProfile({
    required String uid,
    String? name,
    String? organizationId,
    String? organizationName,
    AdminRole? role,
    bool? isActive,
  }) async {
    if (!isSuperAdmin && _currentAdmin?.uid != uid) {
      throw Exception('You can only update your own profile');
    }

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (organizationId != null) updates['organizationId'] = organizationId;
    if (organizationName != null)
      updates['organizationName'] = organizationName;
    if (role != null && isSuperAdmin) updates['role'] = role.value;
    if (isActive != null && isSuperAdmin) updates['isActive'] = isActive;

    if (updates.isNotEmpty) {
      await _firestore
          .collection(_adminUsersCollection)
          .doc(uid)
          .update(updates);

      // Update local state if updating current user
      if (_currentAdmin?.uid == uid) {
        _currentAdmin = _currentAdmin?.copyWith(
          name: name ?? _currentAdmin?.name,
          organizationId: organizationId ?? _currentAdmin?.organizationId,
          organizationName: organizationName ?? _currentAdmin?.organizationName,
          role: role ?? _currentAdmin?.role,
          isActive: isActive ?? _currentAdmin?.isActive,
        );
      }
    }
  }

  /// Get all admins for an organization
  static Future<List<AdminUser>> getOrganizationAdmins(
    String organizationId,
  ) async {
    final snapshot =
        await _firestore
            .collection(_adminUsersCollection)
            .where('organizationId', isEqualTo: organizationId)
            .get();

    return snapshot.docs.map((doc) => AdminUser.fromFirestore(doc)).toList();
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Change password
  static Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No user logged in');
    }

    // Re-authenticate before changing password
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Register a new organization with the creator as super admin
  static Future<AdminUser> registerOrganization({
    required String email,
    required String password,
    required String organizationName,
    required String adminName,
    String? city,
    String? description,
    String category = 'college',
  }) async {
    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create account');
      }

      // Create organization document
      final orgRef = _firestore.collection('organizations').doc();
      final organizationId = orgRef.id;

      await orgRef.set({
        'name': organizationName,
        'city': city,
        'description': description,
        'category': category,
        'createdBy': user.uid,
        'createdByEmail': email.trim(),
        'isVerified': false,
        'eventCount': 0,
        'followerCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create super admin profile
      final adminUser = AdminUser(
        uid: user.uid,
        email: email.trim(),
        name: adminName,
        organizationId: organizationId,
        organizationName: organizationName,
        role: AdminRole.superAdmin,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_adminUsersCollection)
          .doc(user.uid)
          .set(adminUser.toMap());

      _currentAdmin = adminUser;
      return adminUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Request to join an organization as an admin (pending approval)
  static Future<void> requestAdminAccess({
    required String email,
    required String password,
    required String name,
    required String organizationId,
    required String organizationName,
  }) async {
    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create account');
      }

      // Create pending admin request
      await _firestore.collection('adminRequests').doc(user.uid).set({
        'uid': user.uid,
        'email': email.trim(),
        'name': name,
        'organizationId': organizationId,
        'organizationName': organizationName,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // Sign out - user can't login until approved
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Get pending admin requests for an organization (super admin only)
  static Future<List<Map<String, dynamic>>> getPendingRequests(
    String organizationId,
  ) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admins can view pending requests');
    }

    final snapshot =
        await _firestore
            .collection('adminRequests')
            .where('organizationId', isEqualTo: organizationId)
            .where('status', isEqualTo: 'pending')
            .orderBy('requestedAt', descending: true)
            .get();

    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  /// Get all admins in an organization (super admin only)
  static Future<List<AdminUser>> getOrganizationAdminsWithStatus(
    String organizationId,
  ) async {
    final snapshot =
        await _firestore
            .collection(_adminUsersCollection)
            .where('organizationId', isEqualTo: organizationId)
            .get();

    return snapshot.docs.map((doc) => AdminUser.fromFirestore(doc)).toList();
  }

  /// Approve an admin request (super admin only)
  static Future<void> approveAdminRequest(String requestId) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admins can approve requests');
    }

    final requestDoc =
        await _firestore.collection('adminRequests').doc(requestId).get();

    if (!requestDoc.exists) {
      throw Exception('Request not found');
    }

    final requestData = requestDoc.data()!;

    // Create admin user profile
    final adminUser = AdminUser(
      uid: requestData['uid'],
      email: requestData['email'],
      name: requestData['name'],
      organizationId: requestData['organizationId'],
      organizationName: requestData['organizationName'],
      role: AdminRole.scanner, // New admins can only scan
      createdAt: DateTime.now(),
      isActive: true,
    );

    // Use batch write
    final batch = _firestore.batch();

    // Create admin user
    batch.set(
      _firestore.collection(_adminUsersCollection).doc(requestData['uid']),
      adminUser.toMap(),
    );

    // Update request status
    batch.update(_firestore.collection('adminRequests').doc(requestId), {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': _currentAdmin?.uid,
    });

    await batch.commit();
  }

  /// Reject an admin request (super admin only)
  static Future<void> rejectAdminRequest(String requestId) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admins can reject requests');
    }

    final requestDoc =
        await _firestore.collection('adminRequests').doc(requestId).get();

    if (!requestDoc.exists) {
      throw Exception('Request not found');
    }

    final requestData = requestDoc.data()!;

    // Delete the Firebase Auth user
    // Note: This requires admin SDK in production; for now we just mark as rejected

    await _firestore.collection('adminRequests').doc(requestId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': _currentAdmin?.uid,
    });
  }

  /// Remove an admin from organization (super admin only)
  static Future<void> removeAdmin(String adminUid) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admins can remove admins');
    }

    if (adminUid == _currentAdmin?.uid) {
      throw Exception('You cannot remove yourself');
    }

    await _firestore.collection(_adminUsersCollection).doc(adminUid).update({
      'isActive': false,
    });
  }

  /// Promote scanner to org admin (super admin only)
  static Future<void> promoteToOrgAdmin(String adminUid) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admins can promote admins');
    }

    await _firestore.collection(_adminUsersCollection).doc(adminUid).update({
      'role': AdminRole.orgAdmin.value,
    });
  }

  /// Demote org admin to scanner (super admin only)
  static Future<void> demoteToScanner(String adminUid) async {
    if (!isSuperAdmin) {
      throw Exception('Only super admins can demote admins');
    }

    await _firestore.collection(_adminUsersCollection).doc(adminUid).update({
      'role': AdminRole.scanner.value,
    });
  }

  /// Get all organizations (for admin signup to select)
  static Future<List<Map<String, dynamic>>> getAllOrganizations() async {
    final snapshot =
        await _firestore.collection('organizations').orderBy('name').get();

    return snapshot.docs
        .map(
          (doc) => {
            'id': doc.id,
            'name': doc.data()['name'] ?? '',
            'city': doc.data()['city'] ?? '',
            'category': doc.data()['category'] ?? '',
          },
        )
        .toList();
  }

  /// Check if user has pending request
  static Future<Map<String, dynamic>?> checkPendingRequest(String email) async {
    final snapshot =
        await _firestore
            .collection('adminRequests')
            .where('email', isEqualTo: email)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) return null;
    return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
  }

  /// Handle Firebase Auth errors
  static Exception _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email');
      case 'wrong-password':
        return Exception('Incorrect password');
      case 'invalid-email':
        return Exception('Invalid email address');
      case 'user-disabled':
        return Exception('This account has been disabled');
      case 'too-many-requests':
        return Exception('Too many login attempts. Please try again later');
      case 'email-already-in-use':
        return Exception('An account already exists with this email');
      case 'weak-password':
        return Exception('Password is too weak');
      default:
        return Exception('Authentication failed: ${e.message}');
    }
  }
}
