import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContact {
  final String role;
  final String name;
  final String number;
  final IconData icon;

  const EmergencyContact({
    required this.role,
    required this.name,
    required this.number,
    required this.icon,
  });
}

class EmergencyContactsSheet extends StatelessWidget {
  const EmergencyContactsSheet({super.key});

  // TODO: replace placeholder numbers with real contacts before deployment.
  static const List<EmergencyContact> contacts = [
    EmergencyContact(
      role: 'Mine Safety Officer',
      name: 'On-site Safety Officer',
      number: '9335536412',
      icon: Icons.engineering_rounded,
    ),
    EmergencyContact(
      role: 'DGMS Regional Office',
      name: 'Directorate General of Mines Safety',
      number: '9335536412',
      icon: Icons.account_balance_rounded,
    ),
    EmergencyContact(
      role: 'Ambulance',
      name: 'National Ambulance Service',
      number: '108',
      icon: Icons.local_hospital_rounded,
    ),
    EmergencyContact(
      role: 'Fire',
      name: 'National Fire Service',
      number: '101',
      icon: Icons.local_fire_department_rounded,
    ),
    EmergencyContact(
      role: 'Police',
      name: 'National Police Helpline',
      number: '100',
      icon: Icons.local_police_rounded,
    ),
  ];

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const EmergencyContactsSheet(),
    );
  }

  Future<void> _call(BuildContext context, EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Call ${contact.role}?'),
        content: Text('This will open your dialer with ${contact.number} pre-filled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Call Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uri = Uri.parse('tel:${contact.number}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E3EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.phone_in_talk_rounded, color: Color(0xFFD32F2F), size: 22),
                SizedBox(width: 8),
                Text(
                  'Emergency Contacts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A2340)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...contacts.map((c) => _contactRow(context, c)),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(BuildContext context, EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(contact.icon, color: const Color(0xFFD32F2F), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.role, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A2340))),
                Text(contact.number, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _call(context, contact),
            icon: const Icon(Icons.call_rounded, size: 15),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}