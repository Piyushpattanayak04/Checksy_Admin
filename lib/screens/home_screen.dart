import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'event_registration_screen.dart';
import 'event_screen.dart';
import 'qr_scanner_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<String> _events = [];
  
  bool get isSuperAdmin => AuthService.isSuperAdmin;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final snapshot = await FirebaseFirestore.instance.collection('skeleton').get();
    setState(() {
      _events = snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  Future<void> _deleteEvent(String eventName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "$eventName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('skeleton').doc(eventName).delete();
      await _loadEvents();
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget buildHomeTab() {
    // Regular admins can only access the scanner
    if (!isSuperAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Event management is restricted to Super Admins',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _selectedIndex = 1),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Go to Scanner'),
            ),
          ],
        ),
      );
    }
    
    return _events.isEmpty
        ? const Center(child: Text('No events found.'))
        : ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final eventName = _events[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(eventName),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteEvent(eventName),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventScreen(eventName: eventName),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget getBody() {
    switch (_selectedIndex) {
      case 0:
        return buildHomeTab();
      case 1:
        return const QRScannerScreen(eventName: '');
      default:
        return const SizedBox.shrink();
    }
  }

  void _logout() {
    AuthService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clockin Admin'),
        actions: [
          // Show role badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSuperAdmin ? Colors.amber : Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isSuperAdmin ? 'Super Admin' : 'Admin',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: getBody(),
      floatingActionButton: (_selectedIndex == 0 && isSuperAdmin)
          ? FloatingActionButton.extended(
        onPressed: () async {
          final newEventName = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(eventName: ''),
            ),
          );

          if (newEventName != null && newEventName is String && newEventName.isNotEmpty) {
            setState(() {
              _events.add(newEventName);
            });
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[400],
        backgroundColor: Colors.black,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'QR Scanner',
          ),
        ],
      ),
    );
  }
}
