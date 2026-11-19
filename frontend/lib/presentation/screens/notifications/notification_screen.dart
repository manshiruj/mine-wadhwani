import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agent_widgets.dart';

/// In-app alerts: critical findings, overdue/escalated actions, PPE and AQM flags.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  Key _listKey = UniqueKey();

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await sl<ApiClient>().get('/api/v1/alerts');
    return dataList(res.data);
  }

  Future<void> _markAllRead() async {
    await sl<ApiClient>().post('/api/v1/alerts/read', data: {});
    setState(() => _listKey = UniqueKey());
  }

  IconData _icon(String? type) => switch (type) {
        'overdue_action' => Icons.schedule,
        'ppe' => Icons.engineering,
        'aqm' => Icons.air,
        _ => Icons.warning_amber_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: agentAppBar(tr('alerts'), actions: [
        TextButton(
            onPressed: _markAllRead,
            child: Text(tr('mark_all_read'), style: const TextStyle(color: Colors.white))),
      ]),
      body: ApiListView<Map<String, dynamic>>(
        key: _listKey,
        load: _load,
        emptyIcon: Icons.notifications_none_rounded,
        itemBuilder: (c, a, _) {
          final color = severityColor(a['severity'] as String?);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(color),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(_icon(a['type'] as String?), color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text(a['title'] as String? ?? '',
                            style: TextStyle(
                                fontWeight: a['read'] == true ? FontWeight.w500 : FontWeight.w800))),
                    if (a['read'] != true) const CircleAvatar(radius: 4, backgroundColor: Colors.red),
                  ]),
                  const SizedBox(height: 4),
                  Text(a['message'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${a['mine_name']} · ${fmtDateTime(a['createdAt'] as String?)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Home-bar bell with unread alert count (polls every minute).
class UnreadAlertsBell extends StatefulWidget {
  const UnreadAlertsBell({super.key});

  @override
  State<UnreadAlertsBell> createState() => _UnreadAlertsBellState();
}

class _UnreadAlertsBellState extends State<UnreadAlertsBell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final res = await sl<ApiClient>().get('/api/v1/alerts');
      final n = dataList(res.data).where((a) => a['read'] != true).length;
      if (mounted) setState(() => _unread = n);
    } catch (_) {} // offline: keep last count
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr('alerts'),
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
        _poll();
      },
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text('$_unread'),
        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
      ),
    );
  }
}
