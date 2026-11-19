import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agent_widgets.dart';

const _levelColors = {
  'Safe': Color(0xFF10B981),
  'Low': Color(0xFF65A30D),
  'Moderate': Color(0xFFD4A017),
  'High': Color(0xFFEA580C),
  'Severe': Color(0xFFDC2626),
  'Critical': Color(0xFF7F1D1D),
};
Color levelColor(String? l) => _levelColors[l] ?? Colors.grey;

/// Risk Monitor agent: monitored zones (AQM device and/or manual readings) with the latest heating-risk assessment.
class RiskMonitorScreen extends StatefulWidget {
  const RiskMonitorScreen({super.key});

  @override
  State<RiskMonitorScreen> createState() => _RiskMonitorScreenState();
}

class _RiskMonitorScreenState extends State<RiskMonitorScreen> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  Future<List<Map<String, dynamic>>> _load() async =>
      dataList((await sl<ApiClient>().get('/api/v1/risk-monitor/monitors')).data);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: agentAppBar(tr('risk_monitor')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: Text(tr('add_zone')),
        onPressed: () async {
          final ok = await showModalBottomSheet<bool>(
              context: context, isScrollControlled: true, builder: (_) => const _ZoneSheet());
          if (ok == true) _reload();
        },
      ),
      body: ApiListView<Map<String, dynamic>>(
        key: _key,
        load: _load,
        emptyIcon: Icons.sensors,
        itemBuilder: (c, m, reload) => _ZoneCard(m, onChanged: _reload),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final Map<String, dynamic> m;
  final VoidCallback onChanged;
  const _ZoneCard(this.m, {required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final a = (m['latest'] as Map?)?.cast<String, dynamic>();
    final level = a?['level'] as String?;
    final ex = (a?['explanation'] as Map?)?.cast<String, dynamic>() ?? {};
    return InkWell(
      onTap: a == null
          ? null
          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RiskAssessmentScreen(monitor: m, assessment: a))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(level == null ? null : levelColor(level)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${m['zone']} · ${m['mine_name']}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (level != null) Chip2('${tr(level)} · ${a?['risk_index']}', levelColor(level)),
          ]),
          const SizedBox(height: 4),
          Text(
              '${m['environment']} · ${m['coal_grade']} · ${m['device_serial'] != null ? 'AQM ${m['device_serial']}' : tr('manual_only')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          if (a == null)
            Text(tr('no_readings_yet'), style: const TextStyle(color: Colors.grey))
          else ...[
            Text(ex['summary'] as String? ?? '', maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text('${tr('updated')}: ${fmtDateTime(a['createdAt'] as String?)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_note, size: 18),
              label: Text(tr('add_reading')),
              onPressed: () async {
                final ok = await showModalBottomSheet<bool>(
                    context: context, isScrollControlled: true, builder: (_) => _ReadingSheet(monitorId: m['_id'] as String));
                if (ok == true) onChanged();
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Full assessment: final level, safety alerts, ML result + contributions, forecast and the AI explanation.
class RiskAssessmentScreen extends StatelessWidget {
  final Map<String, dynamic> monitor;
  final Map<String, dynamic> assessment;
  const RiskAssessmentScreen({super.key, required this.monitor, required this.assessment});

  Widget _section(String title, List<Widget> children) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimary)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );

  List<Widget> _bullets(List? items) => [for (final i in items ?? const []) Text('• $i')];

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    final ex = (a['explanation'] as Map?)?.cast<String, dynamic>() ?? {};
    final ml = (a['ml'] as Map?)?.cast<String, dynamic>() ?? {};
    final fc = (a['forecast'] as Map?)?.cast<String, dynamic>();
    final contrib = ((ml['contributions'] as Map?) ?? {}).cast<String, dynamic>();
    final probs = ((ml['probabilities'] as Map?) ?? {}).cast<String, dynamic>();
    final level = a['level'] as String?;
    final measured = ((a['measured'] as Map?) ?? {}).cast<String, dynamic>();
    final maxAbs = contrib.values.fold<double>(0.01, (m, v) => (v as num).abs() > m ? (v).abs().toDouble() : m);
    return Scaffold(
      backgroundColor: kBg,
      appBar: agentAppBar('${monitor['zone']}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: cardDecoration(levelColor(level)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(tr(level ?? ''), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: levelColor(level))),
              Chip2('${tr('grade')} ${a['grade']} · ${tr('risk_index')} ${a['risk_index']}', levelColor(level)),
              if (a['baseline_index'] != null) Chip2('${tr('baseline_index')} ${a['baseline_index']}', Colors.grey),
              if (ex['human_review_required'] == true) Chip2(tr('human_review'), severityColor('critical')),
            ]),
            const SizedBox(height: 8),
            Text(ex['summary'] as String? ?? ''),
            if ((ex['risk_interpretation'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(ex['risk_interpretation'] as String, style: TextStyle(color: Colors.grey.shade800)),
            ],
            if ((ex['human_review_reason'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${tr('human_review')}: ${ex['human_review_reason']}', style: TextStyle(color: severityColor('critical'))),
            ],
          ]),
        ),
        if ((ex['active_safety_alerts'] as List? ?? []).isNotEmpty)
          _section(tr('safety_alerts'), _bullets(ex['active_safety_alerts'] as List?)),
        if ((ex['recommended_actions'] as List? ?? []).isNotEmpty)
          _section(tr('recommended_actions'), [
            for (final r in (ex['recommended_actions'] as List).cast<Map>())
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Chip2('${r['procedure_id']}', r['priority'] == 'immediate' ? severityColor('critical') : kPrimary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${r['action']}  (${r['priority'] ?? ''})')),
                ]),
              ),
          ]),
        _section(tr('measured'), [
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final e in measured.entries.where((e) => e.value is num))
              Chip2('${e.key}: ${e.value}', kPrimary),
          ]),
          ..._bullets(ex['measured_facts'] as List?),
        ]),
        _section(tr('ml_model'), [
          Text('${tr('grade')} ${ml['grade']} · ${tr('confidence')} ${((ml['confidence'] as num? ?? 0) * 100).round()}% · '
              '${tr('expected_grade')} ${ml['expected_grade']}'),
          const SizedBox(height: 6),
          for (final e in probs.entries)
            Row(children: [
              SizedBox(width: 70, child: Text('${tr('grade')} ${e.key}', style: const TextStyle(fontSize: 12))),
              Expanded(
                child: LinearProgressIndicator(
                    value: (e.value as num).toDouble(), minHeight: 6, color: kPrimary, backgroundColor: const Color(0xFFE8ECF2)),
              ),
              SizedBox(width: 44, child: Text(' ${((e.value as num) * 100).round()}%', style: const TextStyle(fontSize: 12))),
            ]),
          const SizedBox(height: 10),
          Text(tr('factor_contributions'), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${tr('vs_average')} (${ml['baseline_grade']})', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          for (final e in contrib.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                SizedBox(width: 110, child: Text(e.key, style: const TextStyle(fontSize: 12))),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ((e.value as num).abs() / maxAbs).clamp(0.02, 1.0),
                      child: Container(height: 8, color: (e.value as num) >= 0 ? severityColor('high') : const Color(0xFF10B981)),
                    ),
                  ),
                ),
                SizedBox(width: 56, child: Text(' ${(e.value as num) >= 0 ? '+' : ''}${e.value}', style: const TextStyle(fontSize: 12))),
              ]),
            ),
          ..._bullets(ex['model_inferences'] as List?),
        ]),
        if (fc != null || (ex['forecast_interpretation'] as String? ?? '').isNotEmpty)
          _section(tr('forecast_6h'), [
            if (fc != null) Text('${tr('projected')}: ${tr(fc['projected_level'] as String? ?? '')} · ${fc['projected_values']}'),
            if ((ex['forecast_interpretation'] as String? ?? '').isNotEmpty) Text(ex['forecast_interpretation'] as String),
            ..._bullets(ex['sensor_trends'] as List?),
          ]),
        // System-detected gaps only (the AI's "unknowns" restate the same items).
        if ((ex['data_quality_warnings'] as List? ?? []).isNotEmpty)
          _section(tr('data_quality'), _bullets(ex['data_quality_warnings'] as List?)),
        Text(tr('model_note'), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    );
  }
}

class _ReadingSheet extends StatefulWidget {
  final String monitorId;
  const _ReadingSheet({required this.monitorId});

  @override
  State<_ReadingSheet> createState() => _ReadingSheetState();
}

class _ReadingSheetState extends State<_ReadingSheet> {
  final _c = {
    'coal_temp_c': TextEditingController(),
    'co_ppm': TextEditingController(),
    'co2_ppm': TextEditingController(),
    'o2_pct': TextEditingController(),
    'c2h4_ppm': TextEditingController(),
  };
  static const _labels = {
    'coal_temp_c': 'Coal temperature (°C)',
    'co_ppm': 'CO (ppm)',
    'co2_ppm': 'CO2 (ppm)',
    'o2_pct': 'O2 (%)',
    'c2h4_ppm': 'C2H4 (ppm)',
  };
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    setState(() => (_busy = true, _error = null));
    try {
      await sl<ApiClient>().post('/api/v1/risk-monitor/monitors/${widget.monitorId}/readings',
          data: {for (final e in _c.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } on ServerException catch (e) {
      setState(() => (_busy = false, _error = e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('add_reading'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(tr('reading_hint'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          for (final e in _c.entries)
            TextField(
              controller: e.value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr(_labels[e.key]!)),
            ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary, minimumSize: const Size.fromHeight(48)),
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(tr('assess_now')),
          ),
        ]),
      ),
    );
  }
}

class _ZoneSheet extends StatefulWidget {
  const _ZoneSheet();

  @override
  State<_ZoneSheet> createState() => _ZoneSheetState();
}

class _ZoneSheetState extends State<_ZoneSheet> {
  final _mine = TextEditingController();
  final _zone = TextEditingController();
  final _serial = TextEditingController();
  String _env = 'surface_stockpile';
  String _grade = 'G7';
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    setState(() => (_busy = true, _error = null));
    try {
      await sl<ApiClient>().post('/api/v1/risk-monitor/monitors', data: {
        'mine_name': _mine.text.trim(),
        'zone': _zone.text.trim(),
        'environment': _env,
        'device_serial': _serial.text.trim(),
        'coal_grade': _grade,
      });
      if (mounted) Navigator.pop(context, true);
    } on ServerException catch (e) {
      setState(() => (_busy = false, _error = e.statusCode == 403 ? tr('admin_only') : e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('add_zone'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          TextField(controller: _mine, decoration: InputDecoration(labelText: tr('Mine Name'))),
          TextField(controller: _zone, decoration: InputDecoration(labelText: tr('zone_name'))),
          DropdownButtonFormField<String>(
            initialValue: _env,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('environment')),
            items: const ['surface_stockpile', 'underground_goaf', 'active_workings']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _env = v!),
          ),
          DropdownButtonFormField<String>(
            initialValue: _grade,
            decoration: InputDecoration(labelText: tr('Coal Grade')),
            items: [for (var i = 1; i <= 14; i++) 'G$i'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _grade = v!),
          ),
          TextField(controller: _serial, decoration: InputDecoration(labelText: tr('device_serial_optional'))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary, minimumSize: const Size.fromHeight(48)),
            onPressed: _busy ? null : _save,
            child: Text(tr('submit')),
          ),
        ]),
      ),
    );
  }
}
