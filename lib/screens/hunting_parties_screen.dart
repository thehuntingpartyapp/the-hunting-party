import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'party_details_screen.dart';

class HuntingPartiesScreen extends StatefulWidget {
  const HuntingPartiesScreen({super.key});

  @override
  State<HuntingPartiesScreen> createState() => _HuntingPartiesScreenState();
}

class _HuntingPartiesScreenState extends State<HuntingPartiesScreen> {
  bool _isCreating = false;

  Future<void> _showCreatePartyDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Hunting Party'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Party name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isCreating
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _isCreating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final description = descriptionController.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a party name.')),
                        );
                        return;
                      }

                      Navigator.pop(dialogContext);

                      await _createParty(name: name, description: description);
                    },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _createParty({
    required String name,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be signed in.')));
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      await FirebaseFirestore.instance.collection('huntingParties').add({
        'name': name,
        'description': description,
        'ownerId': user.uid,
        'memberIds': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hunting party created.')));
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to create the hunting party.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Hunting Parties')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _showCreatePartyDialog,
        icon: _isCreating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isCreating ? 'Creating...' : 'Create Party'),
      ),
      body: user == null
          ? const Center(child: Text('Sign in to view your hunting parties.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('huntingParties')
                  .where('memberIds', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load hunting parties.\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final parties = snapshot.data?.docs ?? [];

                if (parties.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_outlined, size: 72),
                          SizedBox(height: 20),
                          Text(
                            'No hunting parties yet',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create your first hunting party to begin.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: parties.length,
                  itemBuilder: (context, index) {
                    final party = parties[index].data();
                    final name = party['name'] as String? ?? 'Unnamed Party';
                    final description = party['description'] as String? ?? '';

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.groups)),
                        title: Text(name),
                        subtitle: Text(
                          description.isEmpty ? 'No description' : description,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PartyDetailsScreen(
                                partyId: parties[index].id,
                                partyName: name,
                                description: description,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
