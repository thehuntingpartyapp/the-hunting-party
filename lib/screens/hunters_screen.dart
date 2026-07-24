import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HuntersScreen extends StatefulWidget {
  const HuntersScreen({
    super.key,
    required this.partyId,
    required this.tripId,
    required this.tripName,
  });

  final String partyId;
  final String tripId;
  final String tripName;

  @override
  State<HuntersScreen> createState() => _HuntersScreenState();
}

class _HuntersScreenState extends State<HuntersScreen> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<String> _memberEmails = [];
  List<Map<String, dynamic>> _campItems = [];
  List<Map<String, dynamic>> _meals = [];
  List<Map<String, dynamic>> _shoppingItems = [];
  List<Map<String, dynamic>> _equipmentItems = [];
  List<Map<String, dynamic>> _vehicles = [];

  bool _isLoading = true;
  String? _errorMessage;

  DocumentReference<Map<String, dynamic>> get _partyReference {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId);
  }

  DocumentReference<Map<String, dynamic>> get _tripReference {
    return _partyReference.collection('trips').doc(widget.tripId);
  }

  @override
  void initState() {
    super.initState();
    _startListeners();
  }

  void _startListeners() {
    _subscriptions.add(
      _partyReference.snapshots().listen(
        (snapshot) {
          final data = snapshot.data();

          if (!mounted) return;

          setState(() {
            _memberEmails = List<String>.from(
              data?['memberEmails'] as List? ?? const [],
            );
            _isLoading = false;
          });
        },
        onError: _handleError,
      ),
    );

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

    _listenToCollection(
      _tripReference.collection('vehicles'),
      (items) => _vehicles = items,
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
          });
        },
        onError: _handleError,
      ),
    );
  }

  void _handleError(Object error) {
    if (!mounted) return;

    setState(() {
      _errorMessage = error.toString();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    super.dispose();
  }

  String _displayName(String email) {
    if (email.isEmpty) return 'Hunter';

    final localPart = email.split('@').first;
    final words = localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return email;

    return words
        .map(
          (word) => '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  List<_HunterAssignment> _assignmentsFor(String email) {
    final normalizedEmail = email.toLowerCase();
    final assignments = <_HunterAssignment>[];

    for (final item in _campItems) {
      if ((item['assignedToEmail'] as String? ?? '').toLowerCase() ==
          normalizedEmail) {
        assignments.add(
          _HunterAssignment(
            icon: Icons.terrain_outlined,
            title: item['itemName'] as String? ?? 'Camp item',
            section: 'Camp',
            isComplete: item['isComplete'] as bool? ?? false,
          ),
        );
      }
    }

    for (final item in _meals) {
      if ((item['assignedToEmail'] as String? ?? '').toLowerCase() ==
          normalizedEmail) {
        assignments.add(
          _HunterAssignment(
            icon: Icons.restaurant_outlined,
            title: item['mealName'] as String? ?? 'Meal',
            section: 'Food',
            isComplete: item['isPrepared'] as bool? ?? false,
          ),
        );
      }
    }

    for (final item in _shoppingItems) {
      if ((item['assignedToEmail'] as String? ?? '').toLowerCase() ==
          normalizedEmail) {
        final purchased = item['isPurchased'] as bool? ?? false;
        final packed = item['isPacked'] as bool? ?? false;

        assignments.add(
          _HunterAssignment(
            icon: Icons.shopping_cart_outlined,
            title: item['itemName'] as String? ?? 'Shopping item',
            section: 'Shopping',
            isComplete: purchased && packed,
          ),
        );
      }
    }

    for (final item in _equipmentItems) {
      if ((item['assignedToEmail'] as String? ?? '').toLowerCase() ==
          normalizedEmail) {
        assignments.add(
          _HunterAssignment(
            icon: Icons.backpack_outlined,
            title: item['itemName'] as String? ?? 'Equipment',
            section: 'Equipment',
            isComplete: item['isPacked'] as bool? ?? false,
          ),
        );
      }
    }

    for (final item in _vehicles) {
      final driver = (item['driver'] as String? ?? '').trim().toLowerCase();

      if (driver == normalizedEmail ||
          driver == _displayName(email).toLowerCase()) {
        assignments.add(
          _HunterAssignment(
            icon: Icons.directions_car_outlined,
            title: item['name'] as String? ?? 'Vehicle',
            section: 'Vehicle',
            isComplete: true,
          ),
        );
      }
    }

    assignments.sort((a, b) {
      final sectionComparison = a.section.compareTo(b.section);

      if (sectionComparison != 0) {
        return sectionComparison;
      }

      return a.title.compareTo(b.title);
    });

    return assignments;
  }

  int _countUnassigned() {
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

  @override
  Widget build(BuildContext context) {
    final unassignedCount = _countUnassigned();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripName} Hunters'),
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
                      'Unable to load hunter assignments.\n$_errorMessage',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _memberEmails.isEmpty
                  ? const Center(
                      child: Text('No hunters found in this party.'),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.assignment_ind_outlined,
                                  size: 34,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_memberEmails.length} '
                                        '${_memberEmails.length == 1 ? 'hunter' : 'hunters'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        unassignedCount == 0
                                            ? 'Every tracked item is assigned.'
                                            : '$unassignedCount '
                                                '${unassignedCount == 1 ? 'item needs' : 'items need'} an owner.',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final email in _memberEmails)
                          _HunterCard(
                            displayName: _displayName(email),
                            email: email,
                            assignments: _assignmentsFor(email),
                          ),
                      ],
                    ),
    );
  }
}

class _HunterCard extends StatelessWidget {
  const _HunterCard({
    required this.displayName,
    required this.email,
    required this.assignments,
  });

  final String displayName;
  final String email;
  final List<_HunterAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final completedCount =
        assignments.where((assignment) => assignment.isComplete).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text(
            displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          assignments.isEmpty
              ? 'No assignments'
              : '$completedCount of ${assignments.length} complete',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              email,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          if (assignments.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'This hunter has not been assigned anything yet.',
              ),
            )
          else
            for (final assignment in assignments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(assignment.icon),
                title: Text(assignment.title),
                subtitle: Text(assignment.section),
                trailing: Icon(
                  assignment.isComplete
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
              ),
        ],
      ),
    );
  }
}

class _HunterAssignment {
  const _HunterAssignment({
    required this.icon,
    required this.title,
    required this.section,
    required this.isComplete,
  });

  final IconData icon;
  final String title;
  final String section;
  final bool isComplete;
}
