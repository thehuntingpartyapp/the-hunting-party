import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'invite_member_screen.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(partyName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partyName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description.isEmpty ? 'No description added.' : description,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _PartyFeatureCard(
            icon: Icons.people_outline,
            title: 'Members',
            subtitle: 'Invite and manage party members.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InviteMemberScreen(
                    partyId: partyId,
                    partyName: partyName,
                  ),
                ),
              );
            },
          ),
          _PartyFeatureCard(
            icon: Icons.calendar_month_outlined,
            title: 'Trips',
            subtitle: 'Plan hunting dates and trip details.',
            onTap: () {
              _showComingSoon(context, 'Trips');
            },
          ),
          _PartyFeatureCard(
            icon: Icons.checklist_outlined,
            title: 'Tasks',
            subtitle: 'Assign and complete party tasks.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TasksScreen(partyId: partyId),
                ),
              );
            },
          ),
          _PartyFeatureCard(
            icon: Icons.backpack_outlined,
            title: 'Equipment',
            subtitle: 'Track who is bringing each item.',
            onTap: () {
              _showComingSoon(context, 'Equipment');
            },
          ),
          _PartyFeatureCard(
            icon: Icons.chat_bubble_outline,
            title: 'Chat',
            subtitle: 'Message everyone in this hunting party.',
            onTap: () {
              _showComingSoon(context, 'Chat');
            },
          ),
          _PartyFeatureCard(
            icon: Icons.photo_library_outlined,
            title: 'Photos',
            subtitle: 'Share and preserve hunting memories.',
            onTap: () {
              _showComingSoon(context, 'Photos');
            },
          ),
          _PartyFeatureCard(
            icon: Icons.emoji_events_outlined,
            title: 'Harvest Log',
            subtitle: 'Record harvest details and photos.',
            onTap: () {
              _showComingSoon(context, 'Harvest Log');
            },
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$featureName is coming next.')));
  }
}

class _PartyFeatureCard extends StatelessWidget {
  const _PartyFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
