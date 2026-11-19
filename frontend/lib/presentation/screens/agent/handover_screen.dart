import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/core/widgets/signature_pad.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agent_widgets.dart';

/// AI-written shift handovers; the incoming supervisor reads and signs off (audit trail).
class HandoverScreen extends StatelessWidget {
  const HandoverScreen({super.key});

  Future<List<Map<String, dynamic>>> _load(bool pending) async {
    final res = await sl<ApiClient>()
        .get('/api/v1/handover', queryParameters: {if (pending) 'pending': 'true'});
    return dataList(res.data);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: agentAppBar(tr('handover'),
            bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: tr('handover_pending')), Tab(text: tr('handover_all'))],
            )),
        body: TabBarView(children: [
          ApiListView<Map<String, dynamic>>(
              load: () => _load(true),
              emptyIcon: Icons.assignment_turned_in_outlined,
              itemBuilder: (c, h, reload) => _HandoverCard(h, onSigned: reload)),
          ApiListView<Map<String, dynamic>>(
              load: () => _load(false),
              itemBuilder: (c, h, reload) => _HandoverCard(h, onSigned: reload)),
        ]),
      ),
    );
  }
}

class _HandoverCard extends StatelessWidget {
  final Map<String, dynamic> h;
  final VoidCallback onSigned;
  const _HandoverCard(this.h, {required this.onSigned});

  @override
  Widget build(BuildContext context) {
    final critical = (h['critical'] as List? ?? []).cast<String>();
    final watch = (h['watchNext'] as List? ?? []).cast<String>();
    final acked = h['acknowledged'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(critical.isNotEmpty ? severityColor('critical') : kPrimary),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${h['mine_name']} · ${h['area'] ?? ''} · ${h['Inspection_type'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          if (h['aiGenerated'] == true) const Chip2('AI', kPrimary),
        ]),
        const SizedBox(height: 4),
        Text(
            'Shift ${h['fromShift']} → ${h['toShift']} · ${fmtDateTime(h['createdAt'] as String?)} · ${tr('handover_from')} ${h['fromName'] ?? '-'}',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),
        Text(h['summary'] as String? ?? '', style: const TextStyle(height: 1.4)),
        if (critical.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(tr('critical'),
              style: TextStyle(color: severityColor('critical'), fontWeight: FontWeight.w700)),
          ...critical.map((c) => _bullet(c, severityColor('critical'))),
        ],
        if (watch.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(tr('watch_next'),
              style: TextStyle(color: severityColor('medium'), fontWeight: FontWeight.w700)),
          ...watch.map((w) => _bullet(w, severityColor('medium'))),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Chip2('${tr('open_actions')}: ${h['openActionCount'] ?? 0}', severityColor('high')),
          const Spacer(),
          if (acked)
            Flexible(
              flex: 4,
              child: Text('${tr('signed_by')} ${h['ackName']} · ${fmtDateTime(h['ackAt'] as String?)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600)),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kPrimary),
              icon: const Icon(Icons.draw_outlined, size: 18),
              label: Text(tr('sign_off')),
              onPressed: () async {
                final ok = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _SignOffSheet(id: h['_id'] as String));
                if (ok == true) onSigned();
              },
            ),
        ]),
      ]),
    );
  }

  Widget _bullet(String t, Color c) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: CircleAvatar(radius: 3, backgroundColor: c)),
          Expanded(child: Text(t)),
        ]),
      );
}

class _SignOffSheet extends StatefulWidget {
  final String id;
  const _SignOffSheet({required this.id});

  @override
  State<_SignOffSheet> createState() => _SignOffSheetState();
}

class _SignOffSheetState extends State<_SignOffSheet> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _pad = GlobalKey<SignaturePadState>();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final png = await _pad.currentState?.toPng();
    if (_name.text.trim().isEmpty || png == null) {
      setState(() => _error = '${tr('your_name')} + ${tr('draw_signature')}');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await sl<ApiClient>().post('/api/v1/handover/${widget.id}/acknowledge', data: {
        'name': _name.text.trim(),
        'note': _note.text.trim(),
        'signature': base64Encode(png),
      });
      if (mounted) Navigator.pop(context, true);
    } on ServerException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('sign_off'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(labelText: tr('your_name'))),
          TextField(controller: _note, decoration: InputDecoration(labelText: tr('note_optional'))),
          const SizedBox(height: 12),
          Row(children: [
            Text(tr('draw_signature'), style: const TextStyle(color: Colors.grey)),
            const Spacer(),
            TextButton(onPressed: () => _pad.currentState?.clear(), child: Text(tr('clear'))),
          ]),
          SignaturePad(key: _pad),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimary, minimumSize: const Size.fromHeight(48)),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(tr('submit')),
          ),
        ]),
      ),
    );
  }
}
