import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({
    super.key,
    required this.partyId,
    required this.tripId,
    required this.tripName,
  });

  final String partyId;
  final String tripId;
  final String tripName;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  bool _isSaving = false;

  CollectionReference<Map<String, dynamic>> get _vehiclesCollection {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(widget.partyId)
        .collection('trips')
        .doc(widget.tripId)
        .collection('vehicles');
  }

  Future<void> _showAddVehicleDialog() async {
    final nameController = TextEditingController();
    final driverController = TextEditingController();
    final capacityController = TextEditingController(text: '1');
    final notesController = TextEditingController();

    String vehicleType = 'Truck';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Vehicle'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle name',
                          hintText: 'Dustin’s Ram 2500',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: vehicleType,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Truck',
                            child: Text('Truck'),
                          ),
                          DropdownMenuItem(
                            value: 'SUV',
                            child: Text('SUV'),
                          ),
                          DropdownMenuItem(
                            value: 'Car',
                            child: Text('Car'),
                          ),
                          DropdownMenuItem(
                            value: 'ATV',
                            child: Text('ATV'),
                          ),
                          DropdownMenuItem(
                            value: 'Side-by-side',
                            child: Text('Side-by-side'),
                          ),
                          DropdownMenuItem(
                            value: 'Trailer',
                            child: Text('Trailer'),
                          ),
                          DropdownMenuItem(
                            value: 'Boat',
                            child: Text('Boat'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            vehicleType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: driverController,
                        decoration: const InputDecoration(
                          labelText: 'Driver or owner',
                          hintText: 'Hunter name or email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: capacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Passenger capacity',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Fuel, trailer, meeting plans...',
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
                                content: Text('Enter a vehicle name.'),
                              ),
                            );
                            return;
                          }

                          final capacity = int.tryParse(
                                capacityController.text.trim(),
                              ) ??
                              1;

                          Navigator.pop(dialogContext);

                          await _addVehicle(
                            name: name,
                            vehicleType: vehicleType,
                            driver: driverController.text.trim(),
                            capacity: capacity < 1 ? 1 : capacity,
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

    nameController.dispose();
    driverController.dispose();
    capacityController.dispose();
    notesController.dispose();
  }

  Future<void> _addVehicle({
    required String name,
    required String vehicleType,
    required String driver,
    required int capacity,
    required String notes,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _vehiclesCollection.add({
        'name': name,
        'vehicleType': vehicleType,
        'driver': driver,
        'capacity': capacity,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle added.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to add the vehicle.',
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

  Future<void> _deleteVehicle(String vehicleId) async {
    try {
      await _vehiclesCollection.doc(vehicleId).delete();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to delete the vehicle.',
          ),
        ),
      );
    }
  }

  IconData _vehicleIcon(String vehicleType) {
    switch (vehicleType) {
      case 'ATV':
      case 'Side-by-side':
        return Icons.motorcycle_outlined;
      case 'Trailer':
        return Icons.rv_hookup_outlined;
      case 'Boat':
        return Icons.directions_boat_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tripName} Vehicles'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _showAddVehicleDialog,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isSaving ? 'Adding...' : 'Add Vehicle'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _vehiclesCollection.orderBy('createdAt').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load vehicles.\n${snapshot.error}',
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

          final vehicles = snapshot.data?.docs ?? [];

          if (vehicles.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 72,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No vehicles yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add trucks, trailers, ATVs, boats, or other vehicles.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final document = vehicles[index];
              final vehicle = document.data();

              final name = vehicle['name'] as String? ?? 'Unnamed vehicle';
              final vehicleType =
                  vehicle['vehicleType'] as String? ?? 'Vehicle';
              final driver = vehicle['driver'] as String? ?? '';
              final capacity = vehicle['capacity'] as int? ?? 1;
              final notes = vehicle['notes'] as String? ?? '';

              final details = <String>[
                vehicleType,
                'Capacity: $capacity',
                if (driver.isNotEmpty) 'Driver: $driver',
                if (notes.isNotEmpty) notes,
              ];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(_vehicleIcon(vehicleType)),
                  ),
                  title: Text(name),
                  subtitle: Text(details.join('\n')),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Delete vehicle',
                    onPressed: () => _deleteVehicle(document.id),
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