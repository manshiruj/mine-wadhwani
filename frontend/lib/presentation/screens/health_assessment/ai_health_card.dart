import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agent_widgets.dart';

/// Shows the AI Health Manager result: rule-engine score/level + LLM suggestions.
class AiHealthCard extends StatelessWidget {
  final Future<Map<String, dynamic>> assessment;
  const AiHealthCard({super.key, required this.assessment});

  static Color levelColor(String? level) => switch (level) {
        'Critical' => severityColor('critical'),
        'High' => severityColor('high'),
        'Moderate' => severityColor('medium'),
        _ => const Color(0xFF10B981),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: assessment,
        builder: (context, snap) {
          final header = Row(children: [
            const Icon(Icons.health_and_safety, color: kPrimary, size: 20),
            const SizedBox(width: 8),
            Text(tr('ai_health_manager'), style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimary)),
          ]);
          if (snap.connectionState != ConnectionState.done) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              header,
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ]);
          }
          if (snap.hasError) {
            final e = snap.error;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              header,
              const SizedBox(height: 8),
              Text(e is ServerException ? e.message : '$e', style: const TextStyle(color: Colors.grey)),
            ]);
          }
          final d = snap.data!;
          final advice = (d['advice'] as Map?)?.cast<String, dynamic>() ?? {};
          final level = d['level'] as String?;
          final color = levelColor(level);
          final actions = ((advice['actions'] as List?) ?? []).cast<Map>();
          final risks = ((advice['key_risks'] as List?) ?? []).cast<String>();
          final workerAdvice = ((advice['worker_advice'] as List?) ?? []).cast<String>();
          final gaps = ((advice['data_gaps'] as List?) ?? []).cast<String>();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            header,
            const SizedBox(height: 10),
            Row(children: [
              Text('${d['score']}', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: color)),
              Text(' / 100', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(width: 10),
              Chip2('${tr(level ?? '')}'.toUpperCase(), color),
              const Spacer(),
              if (advice['human_review_required'] == true)
                Flexible(child: Chip2(tr('human_review'), severityColor('critical'))),
            ]),
            if ((advice['summary'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(advice['summary'] as String, style: const TextStyle(height: 1.4)),
            ],
            if (risks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(tr('key_risks'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ...risks.map((r) => Text('• $r')),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(tr('recommended_actions'), style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final a in actions)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Chip2('${a['urgency'] ?? ''}', a['urgency'] == 'immediate' ? severityColor('critical') : kPrimary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${a['action']} — ${a['owner'] ?? ''}')),
                  ]),
                ),
            ],
            if (workerAdvice.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(tr('worker_advice'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ...workerAdvice.map((w) => Text('• $w')),
            ],
            if (gaps.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${tr('not_measured')}: ${gaps.join(', ')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ]);
        },
      ),
    );
  }
}
