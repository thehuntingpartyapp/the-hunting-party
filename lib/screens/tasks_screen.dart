import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.partyId,
  });

  final String partyId;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _isAdding = false;

  CollectionReference<Map<String, dynamic>> get _tasksCollection {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId)
        .collection('tasks');
  }

  Future<void> _showAddTaskDialog() async {
    final titleController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Task',
                  hintText: 'Bring the generator',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final notes = notesController.text.trim();

                if (title.isEmpty) {
                  return;
                }

                Navigator.pop(dialogContext);

                await _addTask(
                  title: title,
                  notes: notes,
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    notesController.dispose();
  }

  Future<void> _addTask({
    required String title,
    required String notes,
  }) async {
    setState(() {
      _isAdding = true;
    });

    try {
      await _tasksCollection.add({
        'title': title,
        'notes': notes,
        'isComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to add the task.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  Future<void> _toggleTask(
    String taskId,
    bool currentValue,
  ) async {
    await _tasksCollection.doc(taskId).update({
      'isComplete': !currentValue,
    });
  }

  Future<void> _deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAdding ? null : _showAddTaskDialog,
        icon: _isAdding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_task),
        label: Text(_isAdding ? 'Adding...' : 'Add Task'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _tasksCollection
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load tasks.\n${snapshot.error}',
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

          final tasks = snapshot.data?.docs ?? [];

          if (tasks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.checklist_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No tasks yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add tasks so everyone knows what needs to be done.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final document = tasks[index];
              final task = document.data();

              final title = task['title'] as String? ?? 'Untitled task';
              final notes = task['notes'] as String? ?? '';
              final isComplete = task['isComplete'] as bool? ?? false;

              return Card(
                child: CheckboxListTile(
                  value: isComplete,
                  onChanged: (_) {
                    _toggleTask(document.id, isComplete);
                  },
                  title: Text(
                    title,
                    style: TextStyle(
                      decoration:
                          isComplete ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: notes.isEmpty ? null : Text(notes),
                  secondary: IconButton(
                    tooltip: 'Delete task',
                    onPressed: () => _deleteTask(document.id),
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