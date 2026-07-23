import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'hunting_parties_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Hunting Party'),
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to The Hunting Party',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user?.email ?? 'Signed-in hunter',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            Card(
  child: ListTile(
    leading: const Icon(Icons.groups),
    title: const Text('Hunting Parties'),
    subtitle: const Text(
      'Create or join your first hunting party.',
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HuntingPartiesScreen(),
        ),
      );
    },
  ),
),
          ],
        ),
      ),
    );
  }
}