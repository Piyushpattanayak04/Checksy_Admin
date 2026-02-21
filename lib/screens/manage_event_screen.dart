import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';
import '../themes/app_colors.dart';

class ManageEventScreen extends StatefulWidget {
  final String eventName;

  const ManageEventScreen({super.key, required this.eventName});

  @override
  State<ManageEventScreen> createState() => _ManageEventScreenState();
}

class _ManageEventScreenState extends State<ManageEventScreen> {
  List<String> subEvents = [];
  final TextEditingController _controller = TextEditingController();
  bool isLoading = true;
  bool _checkingAccess = true;
  bool _hasAccess = false;
  bool isAcceptingRegistrations = true;
  String eventDisplayName = '';

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('skeleton')
          .doc(widget.eventName)
          .get();

      if (!doc.exists) {
        setState(() {
          _checkingAccess = false;
          _hasAccess = false;
        });
        return;
      }

      final data = doc.data()!;
      final eventOrgId = data['organizationId'] ?? '';
      final currentAdmin = AdminAuthService.currentAdmin;

      // Super admins can access all events
      // Org admins can only access their organization's events
      final hasAccess = AdminAuthService.isSuperAdmin ||
          (currentAdmin != null && currentAdmin.organizationId == eventOrgId);

      if (hasAccess) {
        setState(() {
          _checkingAccess = false;
          _hasAccess = true;
          subEvents = List<String>.from(data['subEvents'] ?? []);
          isAcceptingRegistrations = data['isAcceptingRegistrations'] ?? true;
          eventDisplayName = data['eventName'] ?? widget.eventName;
          isLoading = false;
        });
      } else {
        setState(() {
          _checkingAccess = false;
          _hasAccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _checkingAccess = false;
        _hasAccess = false;
      });
    }
  }

  Future<void> _loadEventData() async {
    final doc = await FirebaseFirestore.instance
        .collection('skeleton')
        .doc(widget.eventName)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        subEvents = List<String>.from(data['subEvents'] ?? []);
        isAcceptingRegistrations = data['isAcceptingRegistrations'] ?? true;
        eventDisplayName = data['eventName'] ?? widget.eventName;
        isLoading = false;
      });
    } else {
      await FirebaseFirestore.instance
          .collection('skeleton')
          .doc(widget.eventName)
          .set({
        'subEvents': [],
        'isAcceptingRegistrations': true,
      });
      setState(() {
        subEvents = [];
        isAcceptingRegistrations = true;
        eventDisplayName = widget.eventName;
        isLoading = false;
      });
    }
  }

  Future<void> _toggleRegistrations(bool value) async {
    setState(() => isAcceptingRegistrations = value);
    
    await FirebaseFirestore.instance
        .collection('skeleton')
        .doc(widget.eventName)
        .update({'isAcceptingRegistrations': value});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Registrations are now open' : 'Registrations are now closed',
          ),
          backgroundColor: value ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  Future<void> _addSubEvent(String name) async {
    if (name.trim().isEmpty) return;
    if (subEvents.contains(name.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This checkpoint already exists'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => subEvents.add(name.trim()));

    await FirebaseFirestore.instance
        .collection('skeleton')
        .doc(widget.eventName)
        .update({'subEvents': subEvents});

    _controller.clear();
  }

  Future<void> _deleteSubEvent(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Checkpoint'),
        content: Text('Are you sure you want to delete "${subEvents[index]}"?'),
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

    if (confirm == true) {
      setState(() => subEvents.removeAt(index));

      await FirebaseFirestore.instance
          .collection('skeleton')
          .doc(widget.eventName)
          .update({'subEvents': subEvents});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.lock,
                    size: 40,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You don\'t have permission to manage this event.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Event'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Name Header
                  Text(
                    eventDisplayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Registration Toggle Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAcceptingRegistrations
                            ? AppColors.success.withOpacity(0.3)
                            : AppColors.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isAcceptingRegistrations
                                ? AppColors.success.withOpacity(0.15)
                                : AppColors.error.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isAcceptingRegistrations
                                ? Icons.how_to_reg
                                : Icons.person_off,
                            color: isAcceptingRegistrations
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Accept Registrations',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAcceptingRegistrations
                                    ? 'Participants can register for this event'
                                    : 'Registrations are currently closed',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isAcceptingRegistrations,
                          onChanged: _toggleRegistrations,
                          activeColor: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Checkpoints Section
                  const Text(
                    'Checkpoints',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add checkpoints for QR scanning (e.g., Check-in, Lunch, Dinner)',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Add Checkpoint Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            labelText: 'Checkpoint Name',
                            hintText: 'e.g., Check-in',
                            prefixIcon: Icon(Icons.add_task),
                          ),
                          onSubmitted: _addSubEvent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _addSubEvent(_controller.text),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Checkpoints List
                  if (subEvents.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.playlist_add,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No checkpoints added yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: subEvents.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex--;
                        final item = subEvents.removeAt(oldIndex);
                        subEvents.insert(newIndex, item);
                        setState(() {});
                        
                        await FirebaseFirestore.instance
                            .collection('skeleton')
                            .doc(widget.eventName)
                            .update({'subEvents': subEvents});
                      },
                      itemBuilder: (context, index) {
                        return Card(
                          key: ValueKey(subEvents[index]),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              subEvents[index],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  color: AppColors.error,
                                  onPressed: () => _deleteSubEvent(index),
                                ),
                                const Icon(
                                  Icons.drag_handle,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
