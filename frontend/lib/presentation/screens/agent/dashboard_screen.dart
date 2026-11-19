import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agent_widgets.dart';

/// Admin dashboard across mines: totals, per-mine compliance (worst first), shift comparison, daily trend.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _days = 30;
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final res = await sl<ApiClient>()
        .get('/api/v1/dashboard/summary', queryParameters: {'days': _days});
    return (res.data as Map)['data'] as Map<String, dynamic>;
  }

  void _setDays(int d) => setState(() {
        _days = d;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: agentAppBar(tr('dashboard')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            final msg = e is ServerException && e.statusCode == 403 ? tr('admin_only') : '$e';
            return Center(
                child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text(msg),
              TextButton(onPressed: () => _setDays(_days), child: Text(tr('retry'))),
            ])));
          }
          final d = snap.data!;
          final t = (d['totals'] as Map).cast<String, dynamic>();
          final mines = (d['mines'] as List).cast<Map<String, dynamic>>();
          final shifts = (d['shifts'] as List).cast<Map<String, dynamic>>();
          final trend = (d['trend'] as List).cast<Map<String, dynamic>>();
          return ListView(padding: const EdgeInsets.all(16), children: [
            // Filter row above the charts
            Row(children: [
              for (final n in [7, 30, 90])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                      label: Text('$n d'), selected: _days == n, onSelected: (_) => _setDays(n)),
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _tile(tr('compliance'), t['compliance'] == null ? '–' : '${t['compliance']}%'),
              _tile(tr('inspections'), '${t['inspections']}'),
              _tile(tr('non_compliant'), '${t['nonCompliant']}'),
              _tile(tr('open_actions'), '${t['openActions']}'),
              _tile(tr('overdue'), '${t['overdueActions']}',
                  warn: (t['overdueActions'] as num? ?? 0) > 0),
            ]),
            const SizedBox(height: 20),
            _section(tr('by_mine'), [
              for (final m in mines)
                _barRow(
                  m['mine_name'] as String,
                  m['compliance'] as num?,
                  '${m['inspections']} ${tr('inspections').toLowerCase()} · ${m['openActions']} ${tr('open').toLowerCase()} · ${m['overdueActions']} ${tr('overdue').toLowerCase()}',
                ),
              if (mines.isEmpty) Text(tr('nothing_here'), style: const TextStyle(color: Colors.grey)),
            ]),
            const SizedBox(height: 16),
            _section(tr('by_shift'), [
              for (final s in shifts)
                _barRow('Shift ${s['shift']}', s['compliance'] as num?,
                    '${s['inspections']} ${tr('inspections').toLowerCase()}'),
            ]),
            const SizedBox(height: 16),
            _section(tr('trend'), [_TrendBars(trend)]),
          ]);
        },
      ),
    );
  }

  Widget _tile(String label, String value, {bool warn = false}) => Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(warn ? severityColor('critical') : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 6),
          Row(children: [
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            if (warn) ...[
              const SizedBox(width: 6),
              Icon(Icons.warning_amber_rounded, color: severityColor('critical'), size: 20),
            ],
          ]),
        ]),
      );

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  /// Horizontal bar 0–100%, value labelled at the end; status shown as icon+text, not colour alone.
  Widget _barRow(String label, num? pct, String sub) {
    final v = (pct ?? 0).toDouble().clamp(0, 100) / 100;
    final low = pct != null && pct < 80;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (low) ...[
            Icon(Icons.error_outline, size: 16, color: severityColor('critical')),
            const SizedBox(width: 4),
            Text('< 80%', style: TextStyle(color: severityColor('critical'), fontSize: 12)),
            const SizedBox(width: 8),
          ],
          Text(pct == null ? '–' : '$pct%', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (c, box) => Stack(children: [
            Container(height: 8, decoration: BoxDecoration(color: const Color(0xFFE8ECF2), borderRadius: BorderRadius.circular(4))),
            Container(
                height: 8,
                width: box.maxWidth * v,
                decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(4))),
          ]),
        ),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ]),
    );
  }
}

/// Daily compliance columns (single series); hover / long-press shows the exact value.
class _TrendBars extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  const _TrendBars(this.trend);

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return Text(tr('nothing_here'), style: const TextStyle(color: Colors.grey));
    const h = 120.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: h,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final d in trend)
            Expanded(
              child: Tooltip(
                message:
                    '${d['date']}: ${d['compliance'] ?? '–'}% · ${d['inspections']} ${tr('inspections').toLowerCase()}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1), // 2px gap between bars
                  child: Container(
                    height: h * ((d['compliance'] as num? ?? 0) / 100).clamp(0.02, 1.0),
                    decoration: const BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Text(trend.first['date'] as String, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const Spacer(),
        Text(trend.last['date'] as String, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ]),
    ]);
  }
}
