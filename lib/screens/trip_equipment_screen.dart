import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TripEquipmentScreen extends StatefulWidget {
  const TripEquipmentScreen({
    super.key,
    required this.partyId,
    required this.tripId,
    required this.tripName,
  });

  final String partyId;
  final String tripId;
  final String tripName;

  @override
  State<TripEquipmentScreen> createState() =>
      _TripEquipmentScreenState();
}

class _TripEquipmentScreenState
    extends State<TripEquipmentScreen> {
  bool _isSaving = false;

  DocumentReference<Map<String, dynamic>> get _partyReference {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId);
  }

  CollectionReference<Map<String, dynamic>>
      get _equipmentCollection {
    return _partyReference
        .collection('trips')
        .doc(widget.tripId)
        .collection('equipment');
  }

  Future<List<String>> _loadMemberEmails() async {
    final partySnapshot = await _partyReference.get();

    return List<String>.from(
      partySnapshot.data()?['memberEmails'] as List? ?? const [],
    );
  }

  Future<void> _showAddEquipmentDialog() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();

    String category = 'Hunting Gear';
    String assignedToEmail = '';

    try {
      final memberEmails = await _loadMemberEmails();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Add Trip Equipment'),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Equipment item',
                            hintText:
                                'Rifle, binoculars, game bags...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _categories
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              category = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            hintText: '1',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: assignedToEmail,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Responsible hunter',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Unassigned'),
                            ),
                            ...memberEmails.map(
                              (email) => DropdownMenuItem(
                                value: email,
                                child: Text(
                                  email,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              assignedToEmail = value ?? '';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            hintText:
                                'Calibre, size, storage location...',
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
                                nameController.text.trim();

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

                            final parsedQuantity = int.tryParse(
                                  quantityController.text.trim(),
                                ) ??
                                1;

                            Navigator.pop(dialogContext);

                            await _addEquipment(
                              itemName: itemName,
                              category: category,
                              quantity:
                                  parsedQuantity < 1 ? 1 : parsedQuantity,
                              assignedToEmail: assignedToEmail,
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
      nameController.dispose();
      quantityController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _addEquipment({
    required String itemName,
    required String category,
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
        'category': category,
        'quantity': quantity,
        'assignedToEmail': assignedToEmail,
        'notes': notes,
        'isPacked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip equipment added.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to add trip equipment.',
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
            error.message ?? 'Unable to update the equipment.',
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
            error.message ?? 'Unable to delete the equipment.',
          ),
        ),
      );
    }
  }

  static const _categories = [
    'Hunting Gear',
    'Firearms and Archery',
    'Optics',
    'Clothing',
    'Footwear',
    'Safety',
    'Navigation',
    'Game Processing',
    'Communication',
    'Personal Gear',
    'Other',
  ];

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Optics':
        return Icons.visibility_outlined;
      case 'Clothing':
        return Icons.checkroom_outlined;
      case 'Footwear':
        return Icons.hiking_outlined;
      case 'Safety':
        return Icons.health_and_safety_outlined;
      case 'Navigation':
        return Icons.explore_outlined;
      case 'Game Processing':
        return Icons.inventory_2_outlined;
      case 'Communication':
        return Icons.cell_tower_outlined;
      case 'Personal Gear':
        return Icons.person_outline;
      case 'Firearms and Archery':
        return Icons.gps_fixed;
      default:
        return Icons.backpack_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripName} Equipment'),
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
        label: Text(
          _isSaving ? 'Adding...' : 'Add Equipment',
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _equipmentCollection
            .orderBy('category')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load trip equipment.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
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
                      'No trip equipment yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add the gear needed specifically for this hunt.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final groupedItems =
              <String,
                  List<
                      QueryDocumentSnapshot<
                          Map<String, dynamic>>>>{};

          for (final document in documents) {
            final category =
                document.data()['category'] as String? ?? 'Other';

            groupedItems
                .putIfAbsent(category, () => [])
                .add(document);
          }

          final categories = groupedItems.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              for (final category in categories) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                  child: Row(
                    children: [
                      Icon(_categoryIcon(category)),
                      const SizedBox(width: 10),
                      Text(
                        category,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                ...groupedItems[category]!.map(
                  (document) {
                    final item = document.data();

                    final itemName =
                        item['itemName'] as String? ??
                            'Unnamed item';

                    final quantity =
                        item['quantity'] as int? ?? 1;

                    final assignedToEmail =
                        item['assignedToEmail']
                                as String? ??
                            '';

                    final notes =
                        item['notes'] as String? ?? '';

                    final isPacked =
                        item['isPacked'] as bool? ?? false;

                    final details = <String>[
                      'Quantity: $quantity',
                      if (assignedToEmail.isNotEmpty)
                        'Responsible: $assignedToEmail',
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
                            decoration: isPacked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(details.join('\n')),
                        isThreeLine: details.length > 1,
                        secondary: IconButton(
                          tooltip: 'Delete equipment',
                          onPressed: () =>
                              _deleteEquipment(document.id),
                          icon: const Icon(
                            Icons.delete_outline,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}