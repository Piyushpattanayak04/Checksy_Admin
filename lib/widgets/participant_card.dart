import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

/// Enhanced Participant Card with expandable details
class ParticipantCard extends StatefulWidget {
  final String memberName;
  final String teamName;
  final Map<String, dynamic> subEvents;
  final VoidCallback? onTap;

  const ParticipantCard({
    super.key,
    required this.memberName,
    required this.teamName,
    required this.subEvents,
    this.onTap,
  });

  @override
  State<ParticipantCard> createState() => _ParticipantCardState();
}

class _ParticipantCardState extends State<ParticipantCard> {
  bool _isExpanded = false;

  String get initials {
    final parts = widget.memberName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.memberName.isNotEmpty 
        ? widget.memberName.substring(0, widget.memberName.length >= 2 ? 2 : 1).toUpperCase()
        : '?';
  }

  int get completedCount => 
      widget.subEvents.values.where((v) => v == true).length;

  int get totalCount => widget.subEvents.length;

  double get completionProgress => 
      totalCount > 0 ? completedCount / totalCount : 0;

  Color get progressColor {
    if (completionProgress >= 1.0) return AppColors.success;
    if (completionProgress >= 0.5) return AppColors.accent;
    if (completionProgress > 0) return AppColors.warning;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isExpanded 
              ? AppColors.primary.withOpacity(0.3) 
              : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _isExpanded = !_isExpanded);
            widget.onTap?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main row
                Row(
                  children: [
                    // Avatar with progress ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: completionProgress,
                            strokeWidth: 3,
                            backgroundColor: AppColors.surface,
                            valueColor: AlwaysStoppedAnimation(progressColor),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    
                    // Name and team
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.memberName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.group_outlined,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.teamName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: progressColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completedCount/$totalCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: progressColor,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Expand icon
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                
                // Expanded details
                if (_isExpanded) ...[
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),
                  
                  // Checkpoint chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.subEvents.entries.map((e) {
                      final isCompleted = e.value == true;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.success.withOpacity(0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCompleted
                                ? AppColors.success.withOpacity(0.3)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 16,
                              color: isCompleted
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              e.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isCompleted
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact participant grid tile for grid view
class ParticipantTile extends StatelessWidget {
  final String memberName;
  final String teamName;
  final Map<String, dynamic> subEvents;
  final VoidCallback? onTap;

  const ParticipantTile({
    super.key,
    required this.memberName,
    required this.teamName,
    required this.subEvents,
    this.onTap,
  });

  String get initials {
    final parts = memberName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return memberName.isNotEmpty 
        ? memberName.substring(0, memberName.length >= 2 ? 2 : 1).toUpperCase()
        : '?';
  }

  int get completedCount => 
      subEvents.values.where((v) => v == true).length;

  int get totalCount => subEvents.length;

  double get completionProgress => 
      totalCount > 0 ? completedCount / totalCount : 0;

  Color get statusColor {
    if (completionProgress >= 1.0) return AppColors.success;
    if (completionProgress >= 0.5) return AppColors.accent;
    if (completionProgress > 0) return AppColors.warning;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with status border
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                memberName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '$completedCount/$totalCount',
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
