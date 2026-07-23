import 'package:flutter/material.dart';

class HuntingPartiesScreen extends StatefulWidget {
  const HuntingPartiesScreen({super.key});

  @override
  State<HuntingPartiesScreen> createState() => _HuntingPartiesScreenState();
}

class _HuntingPartiesScreenState extends State<HuntingPartiesScreen> {
  final List<Map<String, String>> _parties = [];

  Future<void> _showCreatePartyDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();

                if (name.isEmpty) {
                  return;
                }

                setState(() {
                  _parties.add({
                    'name': name,
                    'description': description,
                  });
                });

                Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hunting Parties'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePartyDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Party'),
      ),
      body: _parties.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 72,
                    ),
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
                      'Create your first hunting party to start planning.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _parties.length,
              itemBuilder: (context, index) {
                final party = _parties[index];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.groups),
                    ),
                    title: Text(party['name'] ?? ''),
                    subtitle: Text(
                      party['description']?.isEmpty ?? true
                          ? 'No description'
                          : party['description']!,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}