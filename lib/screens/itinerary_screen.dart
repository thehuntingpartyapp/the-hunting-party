import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({
    super.key,
    required this.partyId,
    required this.tripId,
    required this.tripName,
  });

  final String partyId;
  final String tripId;
  final String tripName;

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  bool _isSaving = false;

  CollectionReference<Map<String, dynamic>> get _itineraryCollection {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId)
        .collection('trips')
        .doc(widget.tripId)
        .collection('itinerary');
  }

  Future<void> _showAddItemDialog() async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final notesController = TextEditingController();

    DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
    TimeOfDay selectedTime = TimeOfDay.now();

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

            Future<void> chooseTime() async {
              final result = await showTimePicker(
                context: context,
                initialTime: selectedTime,
              );

              if (result != null) {
                setDialogState(() {
                  selectedTime = result;
                });
              }
            }

            return AlertDialog(
              title: const Text('Add Itinerary Item'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Activity',
                          hintText: 'Leave camp for morning hunt',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'North trailhead',
                          border: OutlineInputBorder(),
                        ),
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
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_outlined),
                        title: const Text('Time'),
                        subtitle: Text(
                          selectedTime.format(context),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: chooseTime,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Meeting point, supplies, instructions...',
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
                          final title = titleController.text.trim();

                          if (title.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter an activity.'),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(dialogContext);

                          await _addItem(
                            title: title,
                            location: locationController.text.trim(),
                            notes: notesController.text.trim(),
                            date: selectedDate,
                            time: selectedTime,
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

    titleController.dispose();
    locationController.dispose();
    notesController.dispose();
  }

  Future<void> _addItem({
    required String title,
    required String location,
    required String notes,
    required DateTime date,
    required TimeOfDay time,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      await _itineraryCollection.add({
        'title': title,
        'location': location,
        'notes': notes,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'isComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Itinerary item added.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to add the itinerary item.',
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
      await _itineraryCollection.doc(itemId).update({
        'isComplete': !currentlyComplete,
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to update the itinerary.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await _itineraryCollection.doc(itemId).delete();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to delete the itinerary item.',
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

  static String _formatTime(BuildContext context, DateTime date) {
    return TimeOfDay.fromDateTime(date).format(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripName} Itinerary'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _showAddItemDialog,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isSaving ? 'Adding...' : 'Add Activity'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _itineraryCollection
            .orderBy('scheduledAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load the itinerary.\n${snapshot.error}',
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
                    Icon(Icons.route_outlined, size: 72),
                    SizedBox(height: 20),
                    Text(
                      'No itinerary yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add the schedule for each day of the hunt.',
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

              final title =
                  item['title'] as String? ?? 'Unnamed activity';
              final location = item['location'] as String? ?? '';
              final notes = item['notes'] as String? ?? '';
              final isComplete =
                  item['isComplete'] as bool? ?? false;

              final timestamp = item['scheduledAt'] as Timestamp?;
              final scheduledAt = timestamp?.toDate();

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
                    title,
                    style: TextStyle(
                      decoration: isComplete
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (scheduledAt != null)
                        Text(
                          '${_formatDate(scheduledAt)} at '
                          '${_formatTime(context, scheduledAt)}',
                        ),
                      if (location.isNotEmpty)
                        Text('Location: $location'),
                      if (notes.isNotEmpty)
                        Text(
                          notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  secondary: IconButton(
                    tooltip: 'Delete activity',
                    onPressed: () => _deleteItem(document.id),
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