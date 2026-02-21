import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';
import '../models/admin_user_model.dart';
import '../themes/app_colors.dart';
import 'event_registration_screen.dart';
import 'event_screen.dart';
import 'qr_scanner_screen.dart';
import 'login_screen.dart';
import 'admin_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  
  AdminUser? get currentAdmin => AdminAuthService.currentAdmin;
  bool get isSuperAdmin => AdminAuthService.isSuperAdmin;
  bool get isOrgAdmin => AdminAuthService.isOrgAdmin;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    
    try {
      Query query = FirebaseFirestore.instance.collection('skeleton');
      
      // Filter by organization for non-super admins
      if (!isSuperAdmin && currentAdmin?.organizationId != null) {
        query = query.where('organizationId', isEqualTo: currentAdmin!.organizationId);
      }
      
      final snapshot = await query.get();
      
      setState(() {
        _events = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['eventName'] ?? doc.id,
            'description': data['description'] ?? '',
            'bannerUrl': data['bannerUrl'],
            'isAcceptingRegistrations': data['isAcceptingRegistrations'] ?? true,
            'organizationId': data['organizationId'] ?? '',
            'organizationName': data['organizationName'] ?? '',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      // Fallback without organization filter
      final snapshot = await FirebaseFirestore.instance.collection('skeleton').get();
      setState(() {
        _events = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['eventName'] ?? doc.id,
            'description': data['description'] ?? '',
            'bannerUrl': data['bannerUrl'],
            'isAcceptingRegistrations': data['isAcceptingRegistrations'] ?? true,
            'organizationId': data['organizationId'] ?? '',
            'organizationName': data['organizationName'] ?? '',
          };
        }).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEvent(String eventId, String eventName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "$eventName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('skeleton').doc(eventId).delete();
      await _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$eventName" deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // Calculate event stats
  int get _activeEventsCount => _events.where((e) => e['isAcceptingRegistrations'] == true).length;
  int get _closedEventsCount => _events.where((e) => e['isAcceptingRegistrations'] == false).length;

  Widget _buildOrganizationHeader() {
    if (currentAdmin == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                currentAdmin!.organizationName.isNotEmpty
                    ? currentAdmin!.organizationName[0].toUpperCase()
                    : 'O',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentAdmin!.organizationName.isNotEmpty
                      ? currentAdmin!.organizationName
                      : 'All Organizations',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_events.length} events',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSuperAdmin ? AppColors.superAdminBadge : AppColors.adminBadge,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentAdmin!.role.displayName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatTile(
              icon: Icons.event,
              label: 'Total',
              value: _events.length.toString(),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatTile(
              icon: Icons.event_available,
              label: 'Active',
              value: _activeEventsCount.toString(),
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatTile(
              icon: Icons.event_busy,
              label: 'Closed',
              value: _closedEventsCount.toString(),
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final isAccepting = event['isAcceptingRegistrations'] ?? true;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventScreen(eventName: event['id']),
            ),
          ).then((_) => _loadEvents());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Event icon/thumbnail
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: event['bannerUrl'] != null && event['bannerUrl'].isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(
                          event['bannerUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.event,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : const Icon(Icons.event, color: AppColors.textMuted),
              ),
              const SizedBox(width: 16),
              
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (event['description']?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        event['description'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isAccepting
                                ? AppColors.success.withOpacity(0.15)
                                : AppColors.error.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAccepting ? 'Accepting' : 'Closed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isAccepting ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                        if (isSuperAdmin && event['organizationName']?.isNotEmpty == true) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              event['organizationName'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions
              if (isOrgAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.error,
                  onPressed: () => _deleteEvent(event['id'], event['name']),
                ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildOrganizationHeader()),
          
          // Quick Stats Row
          if (_events.isNotEmpty)
            SliverToBoxAdapter(child: _buildQuickStats()),
          
          if (_events.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 64,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No events yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your first event to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Events',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_events.length} total',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildEventCard(_events[index]),
                childCount: _events.length,
              ),
            ),
          ],
          
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const QRScannerScreen(eventName: '');
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _logout() async {
    await AdminAuthService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Events' : 'QR Scanner'),
        actions: [
          // User info
          if (currentAdmin != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  currentAdmin!.displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          // More options menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'manage_admins':
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminManagementScreen(),
                    ),
                  );
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              // Admin management (super admin only)
              if (isSuperAdmin)
                const PopupMenuItem(
                  value: 'manage_admins',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 20, color: AppColors.textSecondary),
                      SizedBox(width: 12),
                      Text('Manage Admins'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _getBody(),
      floatingActionButton: (_selectedIndex == 0 && isOrgAdmin)
          ? FloatingActionButton.extended(
              onPressed: () async {
                final newEventName = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EventDetailsScreen(eventName: ''),
                  ),
                );

                if (newEventName != null && newEventName is String && newEventName.isNotEmpty) {
                  await _loadEvents();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New Event'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scanner',
          ),
        ],
      ),
    );
  }
}
