import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';
import '../themes/app_colors.dart';
import '../widgets/stats_card.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/participant_card.dart';

class DashboardScreen extends StatefulWidget {
  final String eventName;

  const DashboardScreen({super.key, required this.eventName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Access control
  bool _checkingAccess = true;
  bool _hasAccess = false;
  
  // Event data
  String _eventDisplayName = '';
  bool _isAcceptingRegistrations = true;
  List<String> _subEvents = [];
  
  // Filter/Search
  String? _selectedTeam;
  List<String> _teams = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // View mode
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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

      final hasAccess = AdminAuthService.isSuperAdmin ||
          (currentAdmin != null && currentAdmin.organizationId == eventOrgId);

      if (hasAccess) {
        // Load teams
        final teamsSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventName)
            .collection('teams')
            .get();

        setState(() {
          _checkingAccess = false;
          _hasAccess = true;
          _eventDisplayName = data['eventName'] ?? widget.eventName;
          _isAcceptingRegistrations = data['isAcceptingRegistrations'] ?? true;
          _subEvents = List<String>.from(data['subEvents'] ?? []);
          _teams = teamsSnapshot.docs.map((doc) => doc.id).toList();
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

  Future<void> _toggleRegistrations(bool value) async {
    setState(() => _isAcceptingRegistrations = value);
    
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

  // Get all members stream
  Stream<List<Map<String, dynamic>>> _getMembersStream() {
    if (_teams.isEmpty) {
      return Stream.value([]);
    }

    final teamList = _selectedTeam != null ? [_selectedTeam!] : _teams;
    
    // We'll combine streams from all teams
    return FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventName)
        .snapshots()
        .asyncMap((eventDoc) async {
      final List<Map<String, dynamic>> allMembers = [];
      
      // Fetch all teams in parallel using Future.wait
      final memberFutures = teamList.map((team) {
        return FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventName)
            .collection('teams')
            .doc(team)
            .collection('members')
            .get()
            .then((snapshot) => {'team': team, 'docs': snapshot.docs});
      }).toList();
      
      final results = await Future.wait(memberFutures);
      
      for (final result in results) {
        final team = result['team'] as String;
        final docs = result['docs'] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
        
        for (final doc in docs) {
          final data = doc.data();
          final Map<String, dynamic> filteredSubEvents = {};
          for (var subEvent in _subEvents) {
            filteredSubEvents[subEvent] = data[subEvent] ?? false;
          }
          
          allMembers.add({
            'memberName': doc.id,
            'teamName': team,
            'subEvents': filteredSubEvents,
          });
        }
      }
      
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        return allMembers.where((m) {
          final name = m['memberName'].toString().toLowerCase();
          final team = m['teamName'].toString().toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query) || team.contains(query);
        }).toList();
      }
      
      return allMembers;
    });
  }

  // Calculate stats from members
  Map<String, dynamic> _calculateStats(List<Map<String, dynamic>> members) {
    int totalMembers = members.length;
    int fullyCheckedIn = 0;
    int partiallyCheckedIn = 0;
    int notCheckedIn = 0;
    Map<String, int> checkpointCounts = {};
    
    // Initialize checkpoint counts
    for (var checkpoint in _subEvents) {
      checkpointCounts[checkpoint] = 0;
    }
    
    for (var member in members) {
      final subEvents = member['subEvents'] as Map<String, dynamic>;
      int completedCount = 0;
      
      subEvents.forEach((key, value) {
        if (value == true) {
          completedCount++;
          checkpointCounts[key] = (checkpointCounts[key] ?? 0) + 1;
        }
      });
      
      if (completedCount == _subEvents.length && _subEvents.isNotEmpty) {
        fullyCheckedIn++;
      } else if (completedCount > 0) {
        partiallyCheckedIn++;
      } else {
        notCheckedIn++;
      }
    }
    
    return {
      'total': totalMembers,
      'fullyCheckedIn': fullyCheckedIn,
      'partiallyCheckedIn': partiallyCheckedIn,
      'notCheckedIn': notCheckedIn,
      'checkpointCounts': checkpointCounts,
    };
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
      return _buildAccessDenied();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_eventDisplayName),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: 'Participants', icon: Icon(Icons.people, size: 20)),
            Tab(text: 'Progress', icon: Icon(Icons.trending_up, size: 20)),
          ],
        ),
        actions: [
          // Toggle view mode
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getMembersStream(),
        builder: (context, snapshot) {
          final members = snapshot.data ?? [];
          final stats = _calculateStats(members);
          
          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(members, stats),
              _buildParticipantsTab(members, stats),
              _buildProgressTab(members, stats),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccessDenied() {
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
                child: const Icon(Icons.lock, size: 40, color: AppColors.error),
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
                'You don\'t have permission to view this dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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

  // ============== OVERVIEW TAB ==============
  Widget _buildOverviewTab(List<Map<String, dynamic>> members, Map<String, dynamic> stats) {
    return RefreshIndicator(
      onRefresh: _checkAccessAndLoad,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Registration Status Toggle
            _buildRegistrationToggle(),
            const SizedBox(height: 20),
            
            // Stats Cards
            _buildStatsGrid(stats),
            const SizedBox(height: 24),
            
            // Checkpoint Progress Overview
            const Text(
              'Checkpoint Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildCheckpointOverview(stats),
            const SizedBox(height: 24),
            
            // Recent Activity (placeholder for future)
            _buildRecentActivity(members),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _isAcceptingRegistrations 
                ? AppColors.success.withOpacity(0.1)
                : AppColors.error.withOpacity(0.1),
            AppColors.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAcceptingRegistrations
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
              color: _isAcceptingRegistrations
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isAcceptingRegistrations ? Icons.how_to_reg : Icons.person_off,
              color: _isAcceptingRegistrations ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registration Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isAcceptingRegistrations
                      ? 'Participants can register'
                      : 'Registrations are closed',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAcceptingRegistrations,
            onChanged: _toggleRegistrations,
            activeColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate aspect ratio based on available width
        final cardWidth = (constraints.maxWidth - 12) / 2;
        final cardHeight = 150.0; // Fixed height to prevent overflow
        final aspectRatio = cardWidth / cardHeight;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspectRatio,
          children: [
            StatsCard(
              title: 'Total Registered',
              value: '${stats['total']}',
              icon: Icons.groups,
              color: AppColors.primary,
              subtitle: '${_teams.length} teams',
            ),
            StatsCard(
              title: 'Fully Checked In',
              value: '${stats['fullyCheckedIn']}',
              icon: Icons.check_circle,
              color: AppColors.success,
              subtitle: _subEvents.isNotEmpty 
                  ? 'All ${_subEvents.length} checkpoints'
                  : 'No checkpoints',
            ),
            StatsCard(
              title: 'Partially Checked In',
              value: '${stats['partiallyCheckedIn']}',
              icon: Icons.timelapse,
              color: AppColors.warning,
              subtitle: 'In progress',
            ),
            StatsCard(
              title: 'Not Checked In',
              value: '${stats['notCheckedIn']}',
              icon: Icons.pending,
              color: AppColors.error,
              subtitle: 'Waiting',
            ),
          ],
        );
      },
    );
  }

  Widget _buildCheckpointOverview(Map<String, dynamic> stats) {
    final checkpointCounts = stats['checkpointCounts'] as Map<String, int>;
    final total = stats['total'] as int;

    if (_subEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No checkpoints configured',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SubEventProgressRow(
      checkpointCounts: checkpointCounts,
      totalMembers: total,
    );
  }

  Widget _buildRecentActivity(List<Map<String, dynamic>> members) {
    // Show last 5 members with their status
    final recentMembers = members.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Participants',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (recentMembers.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No participants yet',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...recentMembers.map((member) => ParticipantCard(
            memberName: member['memberName'],
            teamName: member['teamName'],
            subEvents: member['subEvents'],
          )),
      ],
    );
  }

  // ============== PARTICIPANTS TAB ==============
  Widget _buildParticipantsTab(List<Map<String, dynamic>> members, Map<String, dynamic> stats) {
    return Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or team...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 12),
              
              // Team Filter Chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('All Teams', _selectedTeam == null, () {
                      setState(() => _selectedTeam = null);
                    }),
                    const SizedBox(width: 8),
                    ..._teams.map((team) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        team, 
                        _selectedTeam == team, 
                        () => setState(() => _selectedTeam = team),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${members.length} participant${members.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _selectedTeam ?? 'All Teams',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Participants List/Grid
        Expanded(
          child: members.isEmpty
              ? _buildEmptyState()
              : _isGridView
                  ? _buildParticipantsGrid(members)
                  : _buildParticipantsList(members),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No participants match your search'
                : 'No participants yet',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(List<Map<String, dynamic>> members) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return ParticipantCard(
          memberName: member['memberName'],
          teamName: member['teamName'],
          subEvents: member['subEvents'],
        );
      },
    );
  }

  Widget _buildParticipantsGrid(List<Map<String, dynamic>> members) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return ParticipantTile(
          memberName: member['memberName'],
          teamName: member['teamName'],
          subEvents: member['subEvents'],
          onTap: () => _showMemberDetails(member),
        );
      },
    );
  }

  void _showMemberDetails(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ParticipantCard(
              memberName: member['memberName'],
              teamName: member['teamName'],
              subEvents: member['subEvents'],
            ),
          ],
        ),
      ),
    );
  }

  // ============== PROGRESS TAB ==============
  Widget _buildProgressTab(List<Map<String, dynamic>> members, Map<String, dynamic> stats) {
    final checkpointCounts = stats['checkpointCounts'] as Map<String, int>;
    final total = stats['total'] as int;

    return RefreshIndicator(
      onRefresh: _checkAccessAndLoad,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Progress Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Progress',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${stats['fullyCheckedIn']} / $total',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'participants fully checked in',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: total > 0 ? stats['fullyCheckedIn'] / total : 0,
                          strokeWidth: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                        Text(
                          total > 0 
                              ? '${((stats['fullyCheckedIn'] / total) * 100).round()}%'
                              : '0%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Checkpoint Progress Section
            const Text(
              'Checkpoint Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            if (_subEvents.isEmpty)
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
                      Icon(Icons.playlist_add, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text(
                        'No checkpoints configured',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._subEvents.map((checkpoint) => CheckpointProgress(
                checkpointName: checkpoint,
                completed: checkpointCounts[checkpoint] ?? 0,
                total: total,
              )),
            
            const SizedBox(height: 24),
            
            // Team Breakdown
            const Text(
              'Team Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTeamBreakdown(members),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamBreakdown(List<Map<String, dynamic>> members) {
    // Group members by team
    final Map<String, List<Map<String, dynamic>>> teamMembers = {};
    for (var member in members) {
      final team = member['teamName'] as String;
      teamMembers.putIfAbsent(team, () => []).add(member);
    }

    if (teamMembers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No teams yet',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: teamMembers.entries.map((entry) {
        final teamName = entry.key;
        final teamMembersList = entry.value;
        
        // Calculate team completion
        int fullyCompleted = 0;
        for (var member in teamMembersList) {
          final subEvents = member['subEvents'] as Map<String, dynamic>;
          final completed = subEvents.values.where((v) => v == true).length;
          if (completed == _subEvents.length && _subEvents.isNotEmpty) {
            fullyCompleted++;
          }
        }
        
        final progress = teamMembersList.isNotEmpty 
            ? fullyCompleted / teamMembersList.length 
            : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    teamName.isNotEmpty ? teamName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${teamMembersList.length} member${teamMembersList.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getProgressColor(progress).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$fullyCompleted / ${teamMembersList.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getProgressColor(progress),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return AppColors.success;
    if (progress >= 0.5) return AppColors.accent;
    if (progress >= 0.25) return AppColors.warning;
    return AppColors.error;
  }
}
