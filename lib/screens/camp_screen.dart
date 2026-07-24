import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CampScreen extends StatefulWidget {
  const CampScreen({
    super.key,
    required this.partyId,
    required this.tripId,
    required this.tripName,
  });

  final String partyId;
  final String tripId;
  final String tripName;

  @override
  State<CampScreen> createState() => _CampScreenState();
}

class _CampScreenState extends State<CampScreen> {
  bool _isSaving = false;

  DocumentReference<Map<String, dynamic>> get _partyReference {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId);
  }

  CollectionReference<Map<String, dynamic>> get _campCollection {
    return _partyReference
        .collection('trips')
        .doc(widget.tripId)
        .collection('camp');
  }

  Future<void> _showAddCampItemDialog() async {
    final itemController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();

    String category = 'Shelter';
    String assignedToEmail = '';

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
                title: const Text('Add Camp Item'),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: itemController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Camp item',
                            hintText: 'Tent, stove, firewood...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Shelter',
                              child: Text('Shelter'),
                            ),
                            DropdownMenuItem(
                              value: 'Cooking',
                              child: Text('Cooking'),
                            ),
                            DropdownMenuItem(
                              value: 'Heat and Fire',
                              child: Text('Heat and Fire'),
                            ),
                            DropdownMenuItem(
                              value: 'Power',
                              child: Text('Power'),
                            ),
                            DropdownMenuItem(
                              value: 'Water',
                              child: Text('Water'),
                            ),
                            DropdownMenuItem(
                              value: 'Safety',
                              child: Text('Safety'),
                            ),
                            DropdownMenuItem(
                              value: 'Tools',
                              child: Text('Tools'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
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
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: assignedToEmail,
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
                                child: Text(email),
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
                            hintText: 'Size, fuel, setup instructions...',
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
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter a camp item.'),
                                ),
                              );
                              return;
                            }

                            final quantity = int.tryParse(
                                  quantityController.text.trim(),
                                ) ??
                                1;

                            Navigator.pop(dialogContext);

                            await _addCampItem(
                              itemName: itemName,
                              category: category,
                              quantity: quantity < 1 ? 1 : quantity,
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
      itemController.dispose();
      quantityController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _addCampItem({
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
      await _campCollection.add({
        'itemName': itemName,
        'category': category,
        'quantity': quantity,
        'assignedToEmail': assignedToEmail,
        'notes': notes,
        'isComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camp item added.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to add the camp item.',
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

  Future<void> _toggleComplete({
    required String itemId,
    required bool currentlyComplete,
  }) async {
    try {
      await _campCollection.doc(itemId).update({
        'isComplete': !currentlyComplete,
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to update the camp item.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteCampItem(String itemId) async {
    try {
      await _campCollection.doc(itemId).delete();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to delete the camp item.',
          ),
        ),
      );
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Cooking':
        return Icons.outdoor_grill_outlined;
      case 'Heat and Fire':
        return Icons.local_fire_department_outlined;
      case 'Power':
        return Icons.power_outlined;
      case 'Water':
        return Icons.water_drop_outlined;
      case 'Safety':
        return Icons.health_and_safety_outlined;
      case 'Tools':
        return Icons.handyman_outlined;
      case 'Shelter':
        return Icons.terrain_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripName} Camp'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _showAddCampItemDialog,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isSaving ? 'Adding...' : 'Add Camp Item'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _campCollection.orderBy('createdAt').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load the camp checklist.\n${snapshot.error}',
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

          final items = snapshot.data?.docs ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.terrain_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No camp items yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Build a shared checklist for setting up camp.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final document = items[index];
              final item = document.data();

              final itemName =
                  item['itemName'] as String? ?? 'Unnamed item';
              final category =
                  item['category'] as String? ?? 'Other';
              final quantity = item['quantity'] as int? ?? 1;
              final assignedToEmail =
                  item['assignedToEmail'] as String? ?? '';
              final notes = item['notes'] as String? ?? '';
              final isComplete =
                  item['isComplete'] as bool? ?? false;

              final details = <String>[
                '$category • Quantity: $quantity',
                if (assignedToEmail.isNotEmpty)
                  'Responsible: $assignedToEmail',
                if (notes.isNotEmpty) notes,
              ];

              return Card(
                child: CheckboxListTile(
                  value: isComplete,
                  onChanged: (_) {
                    _toggleComplete(
                      itemId: document.id,
                      currentlyComplete: isComplete,
                    );
                  },
                  title: Text(
                    itemName,
                    style: TextStyle(
                      decoration: isComplete
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(details.join('\n')),
                  isThreeLine: details.length > 1,
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_categoryIcon(category)),
                      IconButton(
                        tooltip: 'Delete camp item',
                        onPressed: () =>
                            _deleteCampItem(document.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
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