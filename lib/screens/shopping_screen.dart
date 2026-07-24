import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({
    super.key,
    required this.partyId,
    required this.tripId,
    required this.tripName,
  });

  final String partyId;
  final String tripId;
  final String tripName;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mealSubscription;

  bool _isSaving = false;
  bool _isSyncingMeals = false;

  DocumentReference<Map<String, dynamic>> get _partyReference {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId);
  }

  DocumentReference<Map<String, dynamic>> get _tripReference {
    return _partyReference.collection('trips').doc(widget.tripId);
  }

  CollectionReference<Map<String, dynamic>> get _mealsCollection {
    return _tripReference.collection('meals');
  }

  CollectionReference<Map<String, dynamic>> get _shoppingCollection {
    return _tripReference.collection('shopping');
  }

  @override
  void initState() {
    super.initState();

    _mealSubscription = _mealsCollection.snapshots().listen(
      _synchronizeMealIngredients,
      onError: (Object error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to synchronize meal ingredients: $error',
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _mealSubscription?.cancel();
    super.dispose();
  }

  Future<void> _synchronizeMealIngredients(
    QuerySnapshot<Map<String, dynamic>> mealSnapshot,
  ) async {
    if (_isSyncingMeals) return;

    _isSyncingMeals = true;

    try {
      final ingredients = <String, Set<String>>{};

      for (final mealDocument in mealSnapshot.docs) {
        final meal = mealDocument.data();

        final mealName =
            meal['mealName'] as String? ?? 'Unnamed meal';

        final foodItems = List<String>.from(
          meal['foodItems'] as List? ?? const [],
        );

        for (final rawItem in foodItems) {
          final itemName = rawItem.trim();

          if (itemName.isEmpty) continue;

          final normalizedName = itemName.toLowerCase();

          ingredients
              .putIfAbsent(normalizedName, () => <String>{})
              .add(mealName);
        }
      }

      final existingGeneratedItems = await _shoppingCollection
          .where('source', isEqualTo: 'meal')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final entry in ingredients.entries) {
        final itemId = _ingredientDocumentId(entry.key);
        final itemReference = _shoppingCollection.doc(itemId);

        batch.set(
          itemReference,
          {
            'itemName': _displayName(entry.key),
            'normalizedName': entry.key,
            'source': 'meal',
            'mealNames': entry.value.toList()..sort(),
            'category': 'Uncategorized',
            'quantityText': '',
            'assignedToEmail': '',
            'notes': '',
            'isPurchased': false,
            'isPacked': false,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      for (final document in existingGeneratedItems.docs) {
        final normalizedName =
            document.data()['normalizedName'] as String? ?? '';

        if (!ingredients.containsKey(normalizedName)) {
          batch.delete(document.reference);
        }
      }

      await batch.commit();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                'Unable to update the shopping list from meals.',
          ),
        ),
      );
    } finally {
      _isSyncingMeals = false;
    }
  }

  String _ingredientDocumentId(String normalizedName) {
    final safeName = normalizedName
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return 'meal_${safeName.isEmpty ? normalizedName.hashCode : safeName}';
  }

  String _displayName(String normalizedName) {
    if (normalizedName.isEmpty) return normalizedName;

    return normalizedName
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Future<List<String>> _loadMemberEmails() async {
    final partySnapshot = await _partyReference.get();

    return List<String>.from(
      partySnapshot.data()?['memberEmails'] as List? ?? const [],
    );
  }

  Future<void> _showAddItemDialog() async {
    final itemController = TextEditingController();
    final quantityController = TextEditingController();
    final notesController = TextEditingController();

    String category = 'Uncategorized';
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
                title: const Text('Add Shopping Item'),
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
                            labelText: 'Item',
                            hintText: 'Propane, ice, paper towels...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            hintText: '2 bags, 4 dozen, 10 litres...',
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
                                    'Enter a shopping item.',
                                  ),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(dialogContext);

                            await _addManualItem(
                              itemName: itemName,
                              quantityText:
                                  quantityController.text.trim(),
                              category: category,
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

  Future<void> _addManualItem({
    required String itemName,
    required String quantityText,
    required String category,
    required String assignedToEmail,
    required String notes,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _shoppingCollection.add({
        'itemName': itemName,
        'normalizedName': itemName.toLowerCase(),
        'source': 'manual',
        'mealNames': <String>[],
        'category': category,
        'quantityText': quantityText,
        'assignedToEmail': assignedToEmail,
        'notes': notes,
        'isPurchased': false,
        'isPacked': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shopping item added.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to add the shopping item.',
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

  Future<void> _showEditItemDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final item = document.data();

    final quantityController = TextEditingController(
      text: item['quantityText'] as String? ?? '',
    );

    final notesController = TextEditingController(
      text: item['notes'] as String? ?? '',
    );

    String category =
        item['category'] as String? ?? 'Uncategorized';

    if (!_categories.contains(category)) {
      category = 'Uncategorized';
    }

    String assignedToEmail =
        item['assignedToEmail'] as String? ?? '';

    try {
      final memberEmails = await _loadMemberEmails();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  item['itemName'] as String? ?? 'Shopping Item',
                ),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
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
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);

                      await document.reference.update({
                        'quantityText':
                            quantityController.text.trim(),
                        'category': category,
                        'assignedToEmail': assignedToEmail,
                        'notes': notesController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      quantityController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _updateBoolean({
    required String itemId,
    required String field,
    required bool currentValue,
  }) async {
    try {
      await _shoppingCollection.doc(itemId).update({
        field: !currentValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to update the shopping item.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteItem(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final source = document.data()['source'] as String? ?? 'manual';

    if (source == 'meal') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This item comes from a meal. Remove it from the meal instead.',
          ),
        ),
      );
      return;
    }

    await document.reference.delete();
  }

  static const _categories = [
    'Meat',
    'Dairy',
    'Produce',
    'Bakery',
    'Pantry',
    'Frozen',
    'Drinks',
    'Snacks',
    'Camp Supplies',
    'Uncategorized',
  ];

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Meat':
        return Icons.set_meal_outlined;
      case 'Dairy':
        return Icons.local_drink_outlined;
      case 'Produce':
        return Icons.eco_outlined;
      case 'Bakery':
        return Icons.bakery_dining_outlined;
      case 'Frozen':
        return Icons.ac_unit_outlined;
      case 'Drinks':
        return Icons.local_cafe_outlined;
      case 'Snacks':
        return Icons.cookie_outlined;
      case 'Camp Supplies':
        return Icons.terrain_outlined;
      case 'Pantry':
        return Icons.kitchen_outlined;
      default:
        return Icons.shopping_basket_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripName} Shopping'),
        actions: [
          if (_isSyncingMeals)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _showAddItemDialog,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Add Item'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _shoppingCollection
            .orderBy('category')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load the shopping list.\n${snapshot.error}',
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

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Shopping list is empty',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Meal ingredients will appear here automatically.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final groupedItems =
              <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

          for (final document in documents) {
            final category =
                document.data()['category'] as String? ??
                    'Uncategorized';

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
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
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

                    final quantityText =
                        item['quantityText'] as String? ?? '';

                    final assignedToEmail =
                        item['assignedToEmail'] as String? ?? '';

                    final notes =
                        item['notes'] as String? ?? '';

                    final source =
                        item['source'] as String? ?? 'manual';

                    final isPurchased =
                        item['isPurchased'] as bool? ?? false;

                    final isPacked =
                        item['isPacked'] as bool? ?? false;

                    final mealNames = List<String>.from(
                      item['mealNames'] as List? ?? const [],
                    );

                    final subtitleParts = <String>[
                      if (quantityText.isNotEmpty)
                        'Quantity: $quantityText',
                      if (assignedToEmail.isNotEmpty)
                        'Responsible: $assignedToEmail',
                      if (source == 'meal' && mealNames.isNotEmpty)
                        'Meals: ${mealNames.join(', ')}',
                      if (notes.isNotEmpty) notes,
                    ];

                    return Card(
                      child: InkWell(
                        onTap: () => _showEditItemDialog(document),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: isPurchased,
                                onChanged: (_) {
                                  _updateBoolean(
                                    itemId: document.id,
                                    field: 'isPurchased',
                                    currentValue: isPurchased,
                                  );
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: isPurchased
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    if (subtitleParts.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(subtitleParts.join('\n')),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        FilterChip(
                                          selected: isPacked,
                                          avatar: const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 16,
                                          ),
                                          label: Text(
                                            isPacked
                                                ? 'Packed'
                                                : 'Not packed',
                                          ),
                                          onSelected: (_) {
                                            _updateBoolean(
                                              itemId: document.id,
                                              field: 'isPacked',
                                              currentValue: isPacked,
                                            );
                                          },
                                        ),
                                        if (source == 'meal') ...[
                                          const SizedBox(width: 8),
                                          const Chip(
                                            avatar: Icon(
                                              Icons.restaurant_outlined,
                                              size: 16,
                                            ),
                                            label: Text('From meals'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete item',
                                onPressed: () => _deleteItem(document),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
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