import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InvitationsScreen extends StatelessWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Invitations')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('invitations')
            .where('inviteeEmail', isEqualTo: user?.email?.toLowerCase())
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final invitations = snapshot.data?.docs ?? [];

          if (invitations.isEmpty) {
            return const Center(child: Text('No pending invitations'));
          }

          return ListView.builder(
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invitation = invitations[index];

              return Card(
                child: ListTile(
                  title: Text(invitation['partyName']),
                  subtitle: Text('Invited by ${invitation['invitedByEmail']}'),
                  trailing: FilledButton(
                    child: const Text('Accept'),
                    onPressed: () async {
                      await _acceptInvitation(invitation);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Joined hunting party!'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _acceptInvitation(
    QueryDocumentSnapshot<Map<String, dynamic>> invitation,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final firestore = FirebaseFirestore.instance;

    final partyRef = firestore
        .collection('huntingParties')
        .doc(invitation['partyId']);

    final invitationRef = firestore
        .collection('invitations')
        .doc(invitation.id);

    await firestore.runTransaction((transaction) async {
      transaction.update(partyRef, {
        'memberIds': FieldValue.arrayUnion([user.uid]),
        'memberEmails': FieldValue.arrayUnion([
          if (user.email != null) user.email!.toLowerCase(),
        ]),
      });

      transaction.update(invitationRef, {'status': 'accepted'});
    });
  }
}
