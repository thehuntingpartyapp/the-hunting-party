import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'itinerary_screen.dart';
import 'vehicles_screen.dart';

class TripDetailsScreen extends StatelessWidget {
  const TripDetailsScreen({
    super.key,
    required this.partyId,
    required this.tripId,
  });

  final String partyId;
  final String tripId;

  DocumentReference<Map<String, dynamic>> get _tripReference {
    return FirebaseFirestore.instance
        .collection('huntingParties')
        .doc(partyId)
        .collection('trips')
        .doc(tripId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _tripReference.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Hunt Planner'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load this trip.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Hunt Planner'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final trip = snapshot.data?.data();

        if (trip == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Hunt Planner'),
            ),
            body: const Center(
              child: Text('Trip not found.'),
            ),
          );
        }

        final name = trip['name'] as String? ?? 'Unnamed Trip';
        final species = trip['species'] as String? ?? '';
        final locationName = trip['locationName'] as String? ?? '';
        final notes = trip['notes'] as String? ?? '';

        final startTimestamp = trip['startDate'] as Timestamp?;
        final endTimestamp = trip['endDate'] as Timestamp?;

        final startDate = startTimestamp?.toDate();
        final endDate = endTimestamp?.toDate();

        final countdown = _calculateCountdown(startDate);
        final duration = _calculateDuration(
          startDate,
          endDate,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TripHeaderCard(
                tripName: name,
                species: species,
                locationName: locationName,
                startDate: startDate,
                endDate: endDate,
                countdown: countdown,
                duration: duration,
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trip Notes',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(notes),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Hunt Planner',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount:
                    MediaQuery.sizeOf(context).width >= 700 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.08,
                children: [
                  _PlannerTile(
                    icon: Icons.route_outlined,
                    title: 'Itinerary',
                    subtitle: 'Daily hunt plan',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItineraryScreen(
                            partyId: partyId,
                            tripId: tripId,
                            tripName: name,
                          ),
                        ),
                      );
                    },
                  ),
                  _PlannerTile(
                    icon: Icons.groups_outlined,
                    title: 'Hunters',
                    subtitle: 'Attendance and roles',
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Hunters',
                      );
                    },
                  ),
                  _PlannerTile(
                    icon: Icons.directions_car_outlined,
                    title: 'Vehicles',
                    subtitle: 'Trucks and trailers',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VehiclesScreen(
                            partyId: partyId,
                            tripId: tripId,
                            tripName: name,
                          ),
                        ),
                      );
                    },
                  ),
                  _PlannerTile(
                    icon: Icons.terrain_outlined,
                    title: 'Camp',
                    subtitle: 'Camp setup checklist',
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Camp',
                      );
                    },
                  ),
                  _PlannerTile(
                    icon: Icons.restaurant_outlined,
                    title: 'Food',
                    subtitle: 'Meals and supplies',
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Food',
                      );
                    },
                  ),
                  _PlannerTile(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Shopping',
                    subtitle: 'Shared shopping list',
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Shopping',
                      );
                    },
                  ),
                  _PlannerTile(
                    icon: Icons.backpack_outlined,
                    title: 'Equipment',
                    subtitle: 'Trip-specific gear',
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Trip Equipment',
                      );
                    },
                  ),
                  _PlannerTile(
                    icon: Icons.cloud_outlined,
                    title: 'Weather',
                    subtitle: 'Forecast for the hunt',
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Weather',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static int? _calculateCountdown(DateTime? startDate) {
    if (startDate == null) {
      return null;
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final tripStart = DateUtils.dateOnly(startDate);

    return tripStart.difference(today).inDays;
  }

  static int? _calculateDuration(
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null || endDate == null) {
      return null;
    }

    return endDate.difference(startDate).inDays + 1;
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

  void _showComingSoon(
    BuildContext context,
    String featureName,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName is coming next.'),
      ),
    );
  }
}

class _TripHeaderCard extends StatelessWidget {
  const _TripHeaderCard({
    required this.tripName,
    required this.species,
    required this.locationName,
    required this.startDate,
    required this.endDate,
    required this.countdown,
    required this.duration,
  });

  final String tripName;
  final String species;
  final String locationName;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? countdown;
  final int? duration;

  @override
  Widget build(BuildContext context) {
    String countdownText;

    if (countdown == null) {
      countdownText = 'No start date';
    } else if (countdown! > 1) {
      countdownText = '${countdown!} days away';
    } else if (countdown == 1) {
      countdownText = 'Tomorrow';
    } else if (countdown == 0) {
      countdownText = 'Starts today';
    } else {
      countdownText = 'Trip started';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.explore_outlined,
              size: 44,
            ),
            const SizedBox(height: 14),
            Text(
              tripName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (species.isNotEmpty)
              _SummaryRow(
                icon: Icons.pets_outlined,
                label: 'Species',
                value: species,
              ),
            if (locationName.isNotEmpty)
              _SummaryRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: locationName,
              ),
            if (startDate != null && endDate != null)
              _SummaryRow(
                icon: Icons.calendar_month_outlined,
                label: 'Dates',
                value:
                    '${TripDetailsScreen._formatDate(startDate!)} – '
                    '${TripDetailsScreen._formatDate(endDate!)}',
              ),
            if (duration != null)
              _SummaryRow(
                icon: Icons.schedule_outlined,
                label: 'Duration',
                value: '$duration ${duration == 1 ? 'day' : 'days'}',
              ),
            const SizedBox(height: 16),
            Chip(
              avatar: const Icon(
                Icons.hourglass_bottom_outlined,
                size: 18,
              ),
              label: Text(countdownText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class _PlannerTile extends StatelessWidget {
  const _PlannerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 34,
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}