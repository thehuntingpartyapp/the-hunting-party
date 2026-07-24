import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({
    super.key,
    required this.partyId,
    required this.partyName,
  });

  final String partyId;
  final String partyName;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _isSaving = false;

  CollectionReference<Map<String, dynamic>> get _tripsCollection {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId)
        .collection('trips');
  }

  Future<void> _showCreateTripDialog() async {
    final nameController = TextEditingController();
    final speciesController = TextEditingController();
    final locationController = TextEditingController();
    final notesController = TextEditingController();

    DateTime? startDate;
    DateTime? endDate;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectStartDate() async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: startDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(
                  const Duration(days: 365),
                ),
                lastDate: DateTime.now().add(
                  const Duration(days: 3650),
                ),
              );

              if (selectedDate != null) {
                setDialogState(() {
                  startDate = selectedDate;

                  if (endDate != null &&
                      endDate!.isBefore(selectedDate)) {
                    endDate = selectedDate;
                  }
                });
              }
            }

            Future<void> selectEndDate() async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: endDate ?? startDate ?? DateTime.now(),
                firstDate: startDate ?? DateTime.now(),
                lastDate: DateTime.now().add(
                  const Duration(days: 3650),
                ),
              );

              if (selectedDate != null) {
                setDialogState(() {
                  endDate = selectedDate;
                });
              }
            }

            return AlertDialog(
              title: const Text('Create Trip'),
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
                          labelText: 'Trip name',
                          hintText: '2026 Alberta Moose Hunt',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: speciesController,
                        decoration: const InputDecoration(
                          labelText: 'Species',
                          hintText: 'Moose',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location name',
                          hintText: 'Northern Alberta',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.calendar_today_outlined,
                        ),
                        title: const Text('Start date'),
                        subtitle: Text(
                          startDate == null
                              ? 'Select a date'
                              : _formatDate(startDate!),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: selectStartDate,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.event_available_outlined,
                        ),
                        title: const Text('End date'),
                        subtitle: Text(
                          endDate == null
                              ? 'Select a date'
                              : _formatDate(endDate!),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: selectEndDate,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Meeting time, camp details, plans...',
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
                          final name = nameController.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a trip name.'),
                              ),
                            );
                            return;
                          }

                          if (startDate == null || endDate == null) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Select both a start and end date.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(dialogContext);

                          await _createTrip(
                            name: name,
                            species: speciesController.text.trim(),
                            locationName:
                                locationController.text.trim(),
                            notes: notesController.text.trim(),
                            startDate: startDate!,
                            endDate: endDate!,
                          );
                        },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    speciesController.dispose();
    locationController.dispose();
    notesController.dispose();
  }

  Future<void> _createTrip({
    required String name,
    required String species,
    required String locationName,
    required String notes,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _tripsCollection.add({
        'name': name,
        'species': species,
        'locationName': locationName,
        'notes': notes,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip created.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to create the trip.',
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

  Future<void> _deleteTrip(String tripId) async {
    await _tripsCollection.doc(tripId).delete();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.partyName} Trips'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _showCreateTripDialog,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add),
        label: Text(_isSaving ? 'Saving...' : 'Create Trip'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _tripsCollection
            .orderBy('startDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load trips.\n${snapshot.error}',
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

          final trips = snapshot.data?.docs ?? [];

          if (trips.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No trips yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Create a trip to start planning your next hunt.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final document = trips[index];
              final trip = document.data();

              final name = trip['name'] as String? ?? 'Unnamed Trip';
              final species = trip['species'] as String? ?? '';
              final locationName =
                  trip['locationName'] as String? ?? '';
              final notes = trip['notes'] as String? ?? '';

              final startTimestamp =
                  trip['startDate'] as Timestamp?;
              final endTimestamp =
                  trip['endDate'] as Timestamp?;

              final startDate = startTimestamp?.toDate();
              final endDate = endTimestamp?.toDate();

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.calendar_month_outlined),
                  ),
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (species.isNotEmpty) Text(species),
                      if (locationName.isNotEmpty)
                        Text(locationName),
                      if (startDate != null && endDate != null)
                        Text(
                          '${_formatDate(startDate)} – '
                          '${_formatDate(endDate)}',
                        ),
                      if (notes.isNotEmpty)
                        Text(
                          notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete trip',
                    onPressed: () => _deleteTrip(document.id),
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