import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({
    super.key,
    required this.partyId,
    required this.partyName,
  });

  final String partyId;
  final String partyName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$partyName Members'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('huntingParties')
            .doc(partyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load members.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data?.data();

          if (data == null) {
            return const Center(
              child: Text('Hunting party not found.'),
            );
          }

          final ownerId = data['ownerId'] as String? ?? '';

          final memberIds = List<String>.from(
            data['memberIds'] as List? ?? const [],
          );

          final memberEmails = List<String>.from(
            data['memberEmails'] as List? ?? const [],
          );

          if (memberIds.isEmpty) {
            return const Center(
              child: Text('No members found.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: memberIds.length,
            itemBuilder: (context, index) {
              final memberId = memberIds[index];

              final email = index < memberEmails.length
                  ? memberEmails[index]
                  : 'Member ${index + 1}';

              final isOwner = memberId == ownerId;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(email),
                  subtitle: Text(isOwner ? 'Owner' : 'Member'),
                  trailing: isOwner
                      ? const Icon(
                          Icons.workspace_premium_outlined,
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}