import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({
    super.key,
    required this.partyId,
    required this.tripId,
    required this.tripName,
  });

  final String partyId;
  final String tripId;
  final String tripName;

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  bool _isSaving = false;

  DocumentReference<Map<String, dynamic>> get _partyReference {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId);
  }

  CollectionReference<Map<String, dynamic>> get _mealsCollection {
    return _partyReference
        .collection('trips')
        .doc(widget.tripId)
        .collection('meals');
  }

  Future<void> _showAddMealDialog() async {
    final mealNameController = TextEditingController();
    final foodItemsController = TextEditingController();
    final notesController = TextEditingController();

    DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
    String mealType = 'Breakfast';
    String assignedToEmail = '';
    int servings = 1;

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
              Future<void> chooseDate() async {
                final result = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(
                    const Duration(days: 3650),
                  ),
                  lastDate: DateTime.now().add(
                    const Duration(days: 3650),
                  ),
                );

                if (result != null) {
                  setDialogState(() {
                    selectedDate = result;
                  });
                }
              }

              return AlertDialog(
                title: const Text('Add Meal'),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: mealNameController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Meal name',
                            hintText: 'Opening morning breakfast',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: mealType,
                          decoration: const InputDecoration(
                            labelText: 'Meal type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Breakfast',
                              child: Text('Breakfast'),
                            ),
                            DropdownMenuItem(
                              value: 'Lunch',
                              child: Text('Lunch'),
                            ),
                            DropdownMenuItem(
                              value: 'Dinner',
                              child: Text('Dinner'),
                            ),
                            DropdownMenuItem(
                              value: 'Snack',
                              child: Text('Snack'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              mealType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.calendar_month_outlined,
                          ),
                          title: const Text('Date'),
                          subtitle: Text(_formatDate(selectedDate)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: chooseDate,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: '1',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Servings',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            servings = int.tryParse(value) ?? 1;

                            if (servings < 1) {
                              servings = 1;
                            }
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
                          controller: foodItemsController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Food items',
                            hintText:
                                'Eggs, bacon, coffee, hash browns',
                            helperText:
                                'Separate items with commas.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            hintText: 'Prep instructions or details...',
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
                            final mealName =
                                mealNameController.text.trim();

                            if (mealName.isEmpty) {
                              ScaffoldMessenger.of(this.context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter a meal name.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final foodItems = foodItemsController.text
                                .split(',')
                                .map((item) => item.trim())
                                .where((item) => item.isNotEmpty)
                                .toList();

                            Navigator.pop(dialogContext);

                            await _addMeal(
                              mealName: mealName,
                              mealType: mealType,
                              date: selectedDate,
                              servings: servings,
                              assignedToEmail: assignedToEmail,
                              foodItems: foodItems,
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
      mealNameController.dispose();
      foodItemsController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _addMeal({
    required String mealName,
    required String mealType,
    required DateTime date,
    required int servings,
    required String assignedToEmail,
    required List<String> foodItems,
    required String notes,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _mealsCollection.add({
        'mealName': mealName,
        'mealType': mealType,
        'date': Timestamp.fromDate(
          DateUtils.dateOnly(date),
        ),
        'servings': servings,
        'assignedToEmail': assignedToEmail,
        'foodItems': foodItems,
        'notes': notes,
        'isPrepared': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal added.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to add the meal.',
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

  Future<void> _togglePrepared({
    required String mealId,
    required bool currentlyPrepared,
  }) async {
    try {
      await _mealsCollection.doc(mealId).update({
        'isPrepared': !currentlyPrepared,
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to update the meal.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteMeal(String mealId) async {
    try {
      await _mealsCollection.doc(mealId).delete();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to delete the meal.',
          ),
        ),
      );
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  IconData _mealIcon(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return Icons.free_breakfast_outlined;
      case 'Lunch':
        return Icons.lunch_dining_outlined;
      case 'Dinner':
        return Icons.dinner_dining_outlined;
      case 'Snack':
        return Icons.cookie_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripName} Food'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _showAddMealDialog,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isSaving ? 'Adding...' : 'Add Meal'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _mealsCollection
            .orderBy('date')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load meals.\n${snapshot.error}',
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

          final meals = snapshot.data?.docs ?? [];

          if (meals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No meals planned',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add breakfast, lunch, dinner, and snacks for the trip.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: meals.length,
            itemBuilder: (context, index) {
              final document = meals[index];
              final meal = document.data();

              final mealName =
                  meal['mealName'] as String? ?? 'Unnamed meal';
              final mealType =
                  meal['mealType'] as String? ?? 'Other';
              final servings = meal['servings'] as int? ?? 1;
              final assignedToEmail =
                  meal['assignedToEmail'] as String? ?? '';
              final notes = meal['notes'] as String? ?? '';
              final isPrepared =
                  meal['isPrepared'] as bool? ?? false;

              final foodItems = List<String>.from(
                meal['foodItems'] as List? ?? const [],
              );

              final timestamp = meal['date'] as Timestamp?;
              final date = timestamp?.toDate();

              final details = <String>[
                if (date != null) _formatDate(date),
                '$mealType • $servings servings',
                if (assignedToEmail.isNotEmpty)
                  'Responsible: $assignedToEmail',
                if (foodItems.isNotEmpty)
                  'Food: ${foodItems.join(', ')}',
                if (notes.isNotEmpty) notes,
              ];

              return Card(
                child: CheckboxListTile(
                  value: isPrepared,
                  onChanged: (_) {
                    _togglePrepared(
                      mealId: document.id,
                      currentlyPrepared: isPrepared,
                    );
                  },
                  title: Text(
                    mealName,
                    style: TextStyle(
                      decoration: isPrepared
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(details.join('\n')),
                  isThreeLine: true,
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_mealIcon(mealType)),
                      IconButton(
                        tooltip: 'Delete meal',
                        onPressed: () =>
                            _deleteMeal(document.id),
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