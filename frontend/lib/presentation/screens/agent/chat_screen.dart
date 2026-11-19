import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agent_widgets.dart';

/// Safety assistant chat: answers about inspections, risks, actions and rules, using live mine data.
/// shortcut: conversation lives only in memory; persist it if users need history across sessions.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<({String role, String content, bool error})> _messages = [];
  bool _busy = false;

  List<String> get _suggestions => [
        tr('chat_q_risk'),
        tr('chat_q_actions'),
        tr('chat_q_handover'),
        tr('chat_q_haul'),
      ];

  Future<void> _send([String? text]) async {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _messages.add((role: 'user', content: q, error: false));
      _busy = true;
    });
    _toBottom();
    try {
      final res = await sl<ApiClient>().post('/api/v1/ai/chat', data: {
        'messages': _messages
            .where((m) => !m.error)
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
      });
      final reply = ((res.data as Map)['data'] as Map)['reply'] as String;
      setState(() => _messages.add((role: 'assistant', content: reply, error: false)));
    } on ServerException catch (e) {
      setState(() => _messages.add((role: 'assistant', content: e.message, error: true)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _toBottom();
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: agentAppBar(tr('assistant')),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty
              ? ListView(padding: const EdgeInsets.all(20), children: [
                  const Icon(Icons.support_agent, size: 56, color: kPrimary),
                  const SizedBox(height: 12),
                  Text(tr('assistant_intro'),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _suggestions
                        .map((s) => ActionChip(label: Text(s), onPressed: () => _send(s)))
                        .toList(),
                  ),
                ])
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length + (_busy ? 1 : 0),
                  itemBuilder: (c, i) {
                    if (i == _messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      );
                    }
                    return _Bubble(_messages[i]);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: tr('ask_anything'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: kPrimary),
                tooltip: tr('submit'),
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ({String role, String content, bool error}) m;
  const _Bubble(this.m);

  @override
  Widget build(BuildContext context) {
    final mine = m.role == 'user';
    final maxW = MediaQuery.sizeOf(context).width * (mine ? 0.75 : 0.88);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? kPrimary : (m.error ? const Color(0xFFFEF2F2) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: const Color(0xFFE0E3EA)),
        ),
        child: SelectableText.rich(
          TextSpan(children: boldSpans(m.content)),
          style: TextStyle(
              color: mine ? Colors.white : (m.error ? Colors.red.shade800 : const Color(0xFF1A1A2E)),
              height: 1.4),
        ),
      ),
    );
  }
}

/// Renders **bold** segments; everything else plain.
List<TextSpan> boldSpans(String text) {
  final parts = text.split('**');
  return [
    for (var i = 0; i < parts.length; i++)
      TextSpan(text: parts[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null),
  ];
}
