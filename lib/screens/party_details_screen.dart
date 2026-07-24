import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'invite_member_screen.dart';
import 'members_screen.dart';
import 'tasks_screen.dart';
import 'trips_screen.dart';
import 'equipment_screen.dart';

class PartyDetailsScreen extends StatelessWidget {
  const PartyDetailsScreen({
    super.key,
    required this.partyId,
    required this.partyName,
    required this.description,
  });

  final String partyId;
  final String partyName;
  final String description;

  @override
  Widget build(BuildContext context) {
    final partyReference = FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(partyId);

    final tasksReference = partyReference.collection('tasks');

    return Scaffold(
      appBar: AppBar(title: Text(partyName)),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: partyReference.snapshots(),
        builder: (context, partySnapshot) {
          if (partySnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load hunting party.\n'
                  '${partySnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (partySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final partyData = partySnapshot.data?.data();

          if (partyData == null) {
            return const Center(child: Text('Hunting party not found.'));
          }

          final memberIds = List<String>.from(
            partyData['memberIds'] as List? ?? const [],
          );

          final currentName = partyData['name'] as String? ?? partyName;

          final currentDescription =
              partyData['description'] as String? ?? description;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tasksReference.snapshots(),
            builder: (context, tasksSnapshot) {
              final tasks = tasksSnapshot.data?.docs ?? [];

              final openTaskCount = tasks.where((document) {
                final data = document.data();
                return data['isComplete'] != true;
              }).length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PartyHeaderCard(
                    partyName: currentName,
                    description: currentDescription,
                    memberCount: memberIds.length,
                    openTaskCount: openTaskCount,
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 700
                        ? 3
                        : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.08,
                    children: [
                      _DashboardTile(
                        icon: Icons.people_outline,
                        title: 'Members',
                        value: '${memberIds.length}',
                        subtitle: 'Party members',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MembersScreen(
                                partyId: partyId,
                                partyName: currentName,
                              ),
                            ),
                          );
                        },
                      ),
                      _DashboardTile(
                        icon: Icons.person_add_outlined,
                        title: 'Invite',
                        subtitle: 'Add a hunter',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InviteMemberScreen(
                                partyId: partyId,
                                partyName: currentName,
                              ),
                            ),
                          );
                        },
                      ),
                      _DashboardTile(
                        icon: Icons.checklist_outlined,
                        title: 'Tasks',
                        value: '$openTaskCount',
                        subtitle: 'Open tasks',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TasksScreen(partyId: partyId),
                            ),
                          );
                        },
                      ),
                      _DashboardTile(
                        icon: Icons.calendar_month_outlined,
                        title: 'Trips',
                        subtitle: 'Plan a hunt',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripsScreen(
                                partyId: partyId,
                                partyName: currentName,
                              ),
                            ),
                          );
                        },
                      ),
                      _DashboardTile(
                        icon: Icons.backpack_outlined,
                        title: 'Equipment',
                        subtitle: 'Shared gear list',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EquipmentScreen(
                                partyId: partyId,
                                partyName: currentName,
                              ),
                            ),
                          );
                        },
                      ),
                      _DashboardTile(
                        icon: Icons.chat_bubble_outline,
                        title: 'Chat',
                        subtitle: 'Party messages',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                partyId: partyId,
                                partyName: currentName,
                              ),
                            ),
                          );
                        },
                      ),
                      _DashboardTile(
                        icon: Icons.photo_library_outlined,
                        title: 'Photos',
                        subtitle: 'Shared memories',
                        onTap: () {
                          _showComingSoon(context, 'Photos');
                        },
                      ),
                      _DashboardTile(
                        icon: Icons.emoji_events_outlined,
                        title: 'Harvests',
                        subtitle: 'Harvest log',
                        onTap: () {
                          _showComingSoon(context, 'Harvest Log');
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$featureName is coming next.')));
  }
}

class _PartyHeaderCard extends StatelessWidget {
  const _PartyHeaderCard({
    required this.partyName,
    required this.description,
    required this.memberCount,
    required this.openTaskCount,
  });

  final String partyName;
  final String description;
  final int memberCount;
  final int openTaskCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.forest_outlined, size: 42),
            const SizedBox(height: 14),
            Text(
              partyName,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description.isEmpty ? 'No description added.' : description),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.people_outline, size: 18),
                  label: Text(
                    '$memberCount '
                    '${memberCount == 1 ? 'member' : 'members'}',
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    '$openTaskCount open '
                    '${openTaskCount == 1 ? 'task' : 'tasks'}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34),
              const Spacer(),
              if (value != null)
                Text(
                  value!,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
