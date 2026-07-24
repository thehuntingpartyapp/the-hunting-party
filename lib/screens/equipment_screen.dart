import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({
    super.key,
    required this.partyId,
    required this.partyName,
  });

  final String partyId;
  final String partyName;

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  bool _isSaving = false;

  DocumentReference<Map<String, dynamic>> get _partyReference {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId);
  }

  CollectionReference<Map<String, dynamic>> get _equipmentCollection {
    return _partyReference.collection('equipment');
  }

  Future<void> _showAddEquipmentDialog() async {
    final itemController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();

    String? assignedToEmail;

    try {
      final partySnapshot = await _partyReference.get();
      final partyData = partySnapshot.data();

      final memberEmails = List<String>.from(
        partyData?['memberEmails'] as List? ?? const [],
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Add Equipment'),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: itemController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Equipment item',
                            hintText: 'Tent, generator, stove...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: assignedToEmail,
                          decoration: const InputDecoration(
                            labelText: 'Assigned to',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Unassigned'),
                            ),
                            ...memberEmails.map(
                              (email) => DropdownMenuItem<String>(
                                value: email,
                                child: Text(email),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              assignedToEmail = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            final itemName =
                                itemController.text.trim();

                            if (itemName.isEmpty) {
                              ScaffoldMessenger.of(this.context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter an equipment item.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final quantity = int.tryParse(
                                  quantityController.text.trim(),
                                ) ??
                                1;

                            Navigator.pop(dialogContext);

                            await _addEquipment(
                              itemName: itemName,
                              quantity: quantity < 1 ? 1 : quantity,
                              assignedToEmail:
                                  assignedToEmail ?? '',
                              notes: notesController.text.trim(),
                            );
                          },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to load party members.',
          ),
        ),
      );
    } finally {
      itemController.dispose();
      quantityController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _addEquipment({
    required String itemName,
    required int quantity,
    required String assignedToEmail,
    required String notes,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _equipmentCollection.add({
        'itemName': itemName,
        'quantity': quantity,
        'assignedToEmail': assignedToEmail,
        'notes': notes,
        'isPacked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Equipment added.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to add equipment.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _togglePacked({
    required String itemId,
    required bool currentlyPacked,
  }) async {
    try {
      await _equipmentCollection.doc(itemId).update({
        'isPacked': !currentlyPacked,
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to update equipment.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteEquipment(String itemId) async {
    try {
      await _equipmentCollection.doc(itemId).delete();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to delete equipment.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.partyName} Equipment'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _showAddEquipmentDialog,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isSaving ? 'Adding...' : 'Add Equipment'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _equipmentCollection
            .orderBy('createdAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load equipment.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final equipment = snapshot.data?.docs ?? [];

          if (equipment.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.backpack_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No equipment yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Build a shared list of everything needed for the hunt.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: equipment.length,
            itemBuilder: (context, index) {
              final document = equipment[index];
              final item = document.data();

              final itemName =
                  item['itemName'] as String? ?? 'Unnamed item';
              final quantity = item['quantity'] as int? ?? 1;
              final assignedToEmail =
                  item['assignedToEmail'] as String? ?? '';
              final notes = item['notes'] as String? ?? '';
              final isPacked = item['isPacked'] as bool? ?? false;

              final subtitleParts = <String>[
                'Quantity: $quantity',
                if (assignedToEmail.isNotEmpty)
                  'Bringing: $assignedToEmail',
                if (notes.isNotEmpty) notes,
              ];

              return Card(
                child: CheckboxListTile(
                  value: isPacked,
                  onChanged: (_) {
                    _togglePacked(
                      itemId: document.id,
                      currentlyPacked: isPacked,
                    );
                  },
                  title: Text(
                    itemName,
                    style: TextStyle(
                      decoration:
                          isPacked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(subtitleParts.join('\n')),
                  isThreeLine: subtitleParts.length > 1,
                  secondary: IconButton(
                    tooltip: 'Delete equipment',
                    onPressed: () => _deleteEquipment(document.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}