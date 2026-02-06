import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  final String eventName;

  const DashboardScreen({super.key, required this.eventName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? selectedTeam;
  List<String> teams = [];
  bool isLoading = true;
  List<Map<String, dynamic>> members = [];

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventName)
        .collection('teams')
        .get();

    final teamNames = snapshot.docs.map((doc) => doc.id).toList();

    setState(() {
      teams = teamNames;
      selectedTeam = null;
    });

    await _loadMembers(); // Load all members initially
  }

  Future<void> _loadMembers() async {
    setState(() {
      isLoading = true;
      members = [];
    });

    // First fetch the actual subEvents from skeleton to know what fields are valid
    final skeletonDoc = await FirebaseFirestore.instance
        .collection('skeleton')
        .doc(widget.eventName)
        .get();
    
    final List<String> validSubEvents = skeletonDoc.exists 
        ? List<String>.from(skeletonDoc.data()?['subEvents'] ?? [])
        : [];

    final teamList = selectedTeam != null ? [selectedTeam!] : teams;

    // Use parallel fetching
    final List<Future<void>> fetchTasks = teamList.map((team) async {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventName)
          .collection('teams')
          .doc(team)
          .collection('members')
          .get();

      final List<Map<String, dynamic>> teamMembers = membersSnapshot.docs.map((doc) {
        final data = doc.data();
        
        // Filter to only include valid subEvents (exclude collegeName, etc.)
        final Map<String, dynamic> filteredSubEvents = {};
        for (var subEvent in validSubEvents) {
          filteredSubEvents[subEvent] = data[subEvent] ?? false;
        }
        
        return {
          'memberName': doc.id,
          'teamName': team,
          'subEvents': filteredSubEvents,
        };
      }).toList();

      members.addAll(teamMembers);
    }).toList();

    await Future.wait(fetchTasks);

    setState(() {
      isLoading = false;
    });
  }

  Widget _buildStatusCircle(bool status) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final subEvents = member['subEvents'] as Map<String, dynamic>;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member['memberName'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Team: ${member['teamName']}'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: subEvents.entries.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Row(
                      children: [
                        _buildStatusCircle(e.value == true),
                        Text(e.key),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard: ${widget.eventName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Team Filter Dropdown
            Row(
              children: [
                const Text('Filter by Team:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: selectedTeam,
                  hint: const Text('All Teams'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Teams'),
                    ),
                    ...teams.map(
                          (team) => DropdownMenuItem(
                        value: team,
                        child: Text(team),
                      ),
                    ),
                  ],
                  onChanged: (value) async {
                    setState(() {
                      selectedTeam = value;
                    });
                    await _loadMembers();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : Expanded(
              child: members.isEmpty
                  ? const Center(child: Text('No members found.'))
                  : ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) =>
                    _buildMemberCard(members[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
