import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({
    super.key,
    required this.partyId,
    required this.tripId,
    required this.tripName,
  });

  final String partyId;
  final String tripId;
  final String tripName;

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<Map<String, dynamic>> _campItems = [];
  List<Map<String, dynamic>> _meals = [];
  List<Map<String, dynamic>> _shoppingItems = [];
  List<Map<String, dynamic>> _equipmentItems = [];

  bool _isLoading = true;
  String? _errorMessage;

  DocumentReference<Map<String, dynamic>> get _tripReference {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId)
        .collection('trips')
        .doc(widget.tripId);
  }

  @override
  void initState() {
    super.initState();

    _listenToCollection(
      _tripReference.collection('camp'),
      (items) => _campItems = items,
    );

    _listenToCollection(
      _tripReference.collection('meals'),
      (items) => _meals = items,
    );

    _listenToCollection(
      _tripReference.collection('shopping'),
      (items) => _shoppingItems = items,
    );

    _listenToCollection(
      _tripReference.collection('equipment'),
      (items) => _equipmentItems = items,
    );
  }

  void _listenToCollection(
    CollectionReference<Map<String, dynamic>> collection,
    void Function(List<Map<String, dynamic>>) assign,
  ) {
    _subscriptions.add(
      collection.snapshots().listen(
        (snapshot) {
          if (!mounted) return;

          setState(() {
            assign(snapshot.docs.map((doc) => doc.data()).toList());
            _isLoading = false;
          });
        },
        onError: (Object error) {
          if (!mounted) return;

          setState(() {
            _errorMessage = error.toString();
            _isLoading = false;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    super.dispose();
  }

  int _completedCampItems() {
    return _campItems.where((item) {
      return item['isComplete'] == true;
    }).length;
  }

  int _preparedMeals() {
    return _meals.where((item) {
      return item['isPrepared'] == true;
    }).length;
  }

  int _completedShoppingItems() {
    return _shoppingItems.where((item) {
      return item['isPurchased'] == true &&
          item['isPacked'] == true;
    }).length;
  }

  int _packedEquipmentItems() {
    return _equipmentItems.where((item) {
      return item['isPacked'] == true;
    }).length;
  }

  int _unassignedItems() {
    var count = 0;

    count += _campItems.where((item) {
      return (item['assignedToEmail'] as String? ?? '').isEmpty;
    }).length;

    count += _meals.where((item) {
      return (item['assignedToEmail'] as String? ?? '').isEmpty;
    }).length;

    count += _shoppingItems.where((item) {
      return (item['assignedToEmail'] as String? ?? '').isEmpty;
    }).length;

    count += _equipmentItems.where((item) {
      return (item['assignedToEmail'] as String? ?? '').isEmpty;
    }).length;

    return count;
  }

  double _calculateReadiness() {
    final totalItems = _campItems.length +
        _meals.length +
        _shoppingItems.length +
        _equipmentItems.length;

    if (totalItems == 0) {
      return 0;
    }

    final completedItems = _completedCampItems() +
        _preparedMeals() +
        _completedShoppingItems() +
        _packedEquipmentItems();

    return completedItems / totalItems;
  }

  List<String> _buildWarnings() {
    final warnings = <String>[];

    final incompleteCamp =
        _campItems.length - _completedCampItems();

    final incompleteMeals =
        _meals.length - _preparedMeals();

    final incompleteShopping =
        _shoppingItems.length - _completedShoppingItems();

    final incompleteEquipment =
        _equipmentItems.length - _packedEquipmentItems();

    final unassigned = _unassignedItems();

    if (incompleteCamp > 0) {
      warnings.add(
        '$incompleteCamp camp '
        '${incompleteCamp == 1 ? 'item is' : 'items are'} incomplete.',
      );
    }

    if (incompleteMeals > 0) {
      warnings.add(
        '$incompleteMeals '
        '${incompleteMeals == 1 ? 'meal is' : 'meals are'} not prepared.',
      );
    }

    if (incompleteShopping > 0) {
      warnings.add(
        '$incompleteShopping shopping '
        '${incompleteShopping == 1 ? 'item is' : 'items are'} not purchased and packed.',
      );
    }

    if (incompleteEquipment > 0) {
      warnings.add(
        '$incompleteEquipment equipment '
        '${incompleteEquipment == 1 ? 'item is' : 'items are'} not packed.',
      );
    }

    if (unassigned > 0) {
      warnings.add(
        '$unassigned '
        '${unassigned == 1 ? 'item has' : 'items have'} no responsible hunter.',
      );
    }

    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    final readiness = _calculateReadiness();
    final readinessPercent = (readiness * 100).round();
    final warnings = _buildWarnings();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripName} Readiness'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to calculate readiness.\n$_errorMessage',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            Text(
                              'Trip Readiness',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 150,
                              height: 150,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 150,
                                    height: 150,
                                    child: CircularProgressIndicator(
                                      value: readiness,
                                      strokeWidth: 12,
                                    ),
                                  ),
                                  Text(
                                    '$readinessPercent%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              readinessPercent == 100
                                  ? 'This trip is fully ready.'
                                  : 'Keep working through the outstanding items.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProgressSection(
                      icon: Icons.terrain_outlined,
                      title: 'Camp',
                      complete: _completedCampItems(),
                      total: _campItems.length,
                    ),
                    _ProgressSection(
                      icon: Icons.restaurant_outlined,
                      title: 'Food',
                      complete: _preparedMeals(),
                      total: _meals.length,
                    ),
                    _ProgressSection(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Shopping',
                      complete: _completedShoppingItems(),
                      total: _shoppingItems.length,
                    ),
                    _ProgressSection(
                      icon: Icons.backpack_outlined,
                      title: 'Equipment',
                      complete: _packedEquipmentItems(),
                      total: _equipmentItems.length,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Needs Attention',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            if (warnings.isEmpty)
                              const Text(
                                'No outstanding issues found.',
                              )
                            else
                              for (final warning in warnings)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_outlined,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(warning),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.icon,
    required this.title,
    required this.complete,
    required this.total,
  });

  final IconData icon;
  final String title;
  final int complete;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : complete / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              icon,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text('$complete / $total'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}