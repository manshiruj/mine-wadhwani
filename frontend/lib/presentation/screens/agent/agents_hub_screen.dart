import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agent_widgets.dart';
import 'package:mine_wadhwani/presentation/screens/agent/risk_monitor_screen.dart';

/// All AI agents with their trigger and live activity (refreshes every 10 s).
class AgentsHubScreen extends StatefulWidget {
  const AgentsHubScreen({super.key});

  @override
  State<AgentsHubScreen> createState() => _AgentsHubScreenState();
}

class _AgentsHubScreenState extends State<AgentsHubScreen> {
  List<Map<String, dynamic>>? _agents;
  String? _error;
  Timer? _timer;

  static const _icons = {
    'shift': Icons.assignment_turned_in,
    'escalation': Icons.schedule,
    'health': Icons.health_and_safety,
    'risk_monitor': Icons.local_fire_department,
    'assistant': Icons.support_agent,
    'voice': Icons.mic,
  };

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await sl<ApiClient>().get('/api/v1/agents');
      if (mounted) setState(() => (_agents = dataList(res.data), _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Color _statusColor(String? s) => switch (s) {
        'running' => const Color(0xFF2563EB),
        'ok' => const Color(0xFF10B981),
        'error' => severityColor('critical'),
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final agents = _agents;
    return Scaffold(
      backgroundColor: kBg,
      appBar: agentAppBar(tr('ai_agents'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: tr('retry')),
      ]),
      body: agents == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth >= 1000 ? 3 : (box.maxWidth >= 640 ? 2 : 1);
              return ListView(padding: const EdgeInsets.all(16), children: [
                Text(tr('agents_intro'), style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final a in agents)
                      SizedBox(
                        width: (box.maxWidth - 32 - 12 * (cols - 1)) / cols,
                        child: _AgentCard(
                          a: a,
                          icon: _icons[a['id']] ?? Icons.smart_toy,
                          statusColor: _statusColor(a['lastStatus'] as String?),
                          onOpen: a['id'] == 'risk_monitor'
                              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiskMonitorScreen()))
                              : null,
                        ),
                      ),
                  ],
                ),
              ]);
            }),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final Map<String, dynamic> a;
  final IconData icon;
  final Color statusColor;
  final VoidCallback? onOpen;
  const _AgentCard({required this.a, required this.icon, required this.statusColor, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final running = (a['running'] as num? ?? 0) > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: kPrimary.withValues(alpha: 0.1), child: Icon(icon, color: kPrimary)),
          const SizedBox(width: 10),
          Expanded(child: Text(a['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800))),
          if (running) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 6),
          Chip2((a['lastStatus'] as String? ?? 'idle').toUpperCase(), statusColor),
        ]),
        const SizedBox(height: 8),
        Text(a['description'] as String? ?? '', style: const TextStyle(fontSize: 13, height: 1.35)),
        const SizedBox(height: 8),
        Text('${tr('trigger')}: ${a['trigger'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        Text('${tr('runs')}: ${a['runs'] ?? 0} · ${tr('last_run')}: ${fmtDateTime(a['lastRunAt'] as String?)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        if ((a['lastSummary'] as String? ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('→ ${a['lastSummary']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ),
        if (onOpen != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: onOpen, icon: const Icon(Icons.open_in_new, size: 16), label: Text(tr('open_monitor'))),
          ),
      ]),
    );
  }
}
