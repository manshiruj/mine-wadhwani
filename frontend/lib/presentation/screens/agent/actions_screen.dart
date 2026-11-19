import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agent_widgets.dart';

/// Corrective actions raised automatically from every "NO" answer; overdue ones escalate to admins.
class ActionsScreen extends StatelessWidget {
  const ActionsScreen({super.key});

  Future<List<Map<String, dynamic>>> _load(String status) async {
    final res = await sl<ApiClient>().get('/api/v1/actions', queryParameters: {'status': status});
    return dataList(res.data);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: agentAppBar(tr('actions'),
            bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: tr('open')), Tab(text: tr('closed'))],
            )),
        body: TabBarView(children: [
          ApiListView<Map<String, dynamic>>(
              load: () => _load('open'),
              emptyIcon: Icons.task_alt,
              itemBuilder: (c, a, reload) => _ActionCard(a, onClosed: reload)),
          ApiListView<Map<String, dynamic>>(
              load: () => _load('closed'),
              itemBuilder: (c, a, reload) => _ActionCard(a, onClosed: reload)),
        ]),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final Map<String, dynamic> a;
  final VoidCallback onClosed;
  const _ActionCard(this.a, {required this.onClosed});

  Future<void> _close(BuildContext context) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('close_action')),
        content: TextField(
            controller: note,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(hintText: tr('fix_note'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('submit'))),
        ],
      ),
    );
    if (ok != true || note.text.trim().isEmpty) return;
    try {
      await sl<ApiClient>().patch('/api/v1/actions/${a['_id']}/close', data: {'note': note.text.trim()});
      onClosed();
    } on ServerException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sev = a['severity'] as String?;
    final open = a['status'] == 'open';
    final due = DateTime.tryParse(a['dueAt'] as String? ?? '');
    final overdue = open && due != null && due.isBefore(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(severityColor(sev)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Chip2((sev ?? '').toUpperCase(), severityColor(sev)),
          const SizedBox(width: 6),
          if (overdue) Chip2(tr('overdue'), severityColor('critical')),
          if (a['escalated'] == true) ...[const SizedBox(width: 6), Chip2(tr('escalated'), kPrimary)],
          const SizedBox(width: 8),
          Expanded(
            child: Text('${a['mine_name']} · ${a['area'] ?? ''}',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(a['questionText'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
        if ((a['issue'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('“${a['issue']}”', style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 6),
        Text('→ ${a['action'] ?? ''}'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text('${tr('owner')}: ${a['owner'] ?? '-'} · ${tr('due')}: ${fmtDateTime(a['dueAt'] as String?)}',
                style: TextStyle(fontSize: 12, color: overdue ? severityColor('critical') : Colors.grey.shade700)),
          ),
          const SizedBox(width: 8),
          if (open)
            OutlinedButton.icon(
                onPressed: () => _close(context),
                icon: const Icon(Icons.check, size: 18),
                label: Text(tr('close_action')))
          else
            Flexible(
              child: Text('✓ ${a['closedName'] ?? ''}: ${a['closeNote'] ?? ''}',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
        ]),
      ]),
    );
  }
}
