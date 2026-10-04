/// Small shared widgets for session delivery mode (offline / online).
library;

import 'package:flutter/material.dart';

import '../models/room.dart';

/// Badge showing whether a session is delivered online or in person.
///
/// Shows "Online" with a wifi icon for remote sessions and "Offline" with a
/// school icon otherwise. Use [ModeBadge.visible] to render nothing for the
/// common offline case and avoid a badge on every single card.
class ModeBadge extends StatelessWidget {
  const ModeBadge({super.key, required this.isOnline}) : _onlyOnline = false;

  /// Renders the badge only when [isOnline] is true; renders nothing offline.
  const ModeBadge.visible({super.key, required this.isOnline}) : _onlyOnline = true;

  final bool isOnline;
  final bool _onlyOnline;

  @override
  Widget build(BuildContext context) {
    if (_onlyOnline && !isOnline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.school,
            size: 12,
            color: isOnline ? Colors.blue.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 3),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isOnline ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Human-readable label for a room's type.
String roomTypeLabel(RoomType? type) => switch (type) {
  RoomType.lab => 'Laboratorium',
  RoomType.online => 'Online',
  RoomType.kelas => 'Ruang Kelas',
  null => 'Ruangan',
};

/// Icon matching a room's type.
IconData roomTypeIcon(RoomType? type) => switch (type) {
  RoomType.lab => Icons.computer,
  RoomType.online => Icons.cloud_outlined,
  RoomType.kelas => Icons.meeting_room,
  null => Icons.meeting_room,
};