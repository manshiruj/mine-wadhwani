import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agent_widgets.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef VoiceQuestion = ({String code, String text});
typedef VoiceAnswer = ({String code, String answer, String comment});

/// Header mic button: opens the voice-fill sheet for the given YES/NO questions.
class VoiceFillButton extends StatelessWidget {
  final List<VoiceQuestion> questions;
  final void Function(List<VoiceAnswer>) onApply;
  const VoiceFillButton({super.key, required this.questions, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('voice_fill'),
      child: GestureDetector(
        onTap: questions.isEmpty
            ? null
            : () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => VoiceFillSheet(questions: questions, onApply: onApply),
                ),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class VoiceFillSheet extends StatefulWidget {
  final List<VoiceQuestion> questions;
  final void Function(List<VoiceAnswer>) onApply;
  const VoiceFillSheet({super.key, required this.questions, required this.onApply});

  @override
  State<VoiceFillSheet> createState() => _VoiceFillSheetState();
}

class _VoiceFillSheetState extends State<VoiceFillSheet> {
  final _stt = SpeechToText();
  final _text = TextEditingController();
  bool _sttReady = false;
  bool _listening = false;
  bool _busy = false;
  String _base = ''; // text before the current listening session
  String? _error;
  int? _filled;
  List<String> _followUp = [];

  @override
  void initState() {
    super.initState();
    _stt
        .initialize(
          onStatus: (s) {
            if (mounted && (s == 'done' || s == 'notListening')) setState(() => _listening = false);
          },
          onError: (e) {
            if (mounted) setState(() => _listening = false);
          },
        )
        .then((ok) => mounted ? setState(() => _sttReady = ok) : null)
        .catchError((_) => null); // no mic / unsupported browser: typing still works
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    _base = _text.text.trim();
    setState(() => _listening = true);
    await _stt.listen(
      localeId: AppLanguage.speechLocales[AppLanguage.current.value],
      listenOptions: SpeechListenOptions(listenMode: ListenMode.dictation, partialResults: true),
      pauseFor: const Duration(seconds: 6),
      listenFor: const Duration(minutes: 2),
      onResult: (r) {
        _text.text = [_base, r.recognizedWords].where((s) => s.isNotEmpty).join(' ');
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      },
    );
  }

  Future<void> _fill() async {
    if (_listening) await _stt.stop();
    if (_text.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await sl<ApiClient>().post('/api/v1/ai/voice-fill', data: {
        'transcript': _text.text.trim(),
        'questions': widget.questions.map((q) => {'code': q.code, 'text': q.text}).toList(),
      });
      final data = (res.data as Map)['data'] as Map;
      final answers = ((data['answers'] as List?) ?? [])
          .cast<Map>()
          .map<VoiceAnswer>((a) => (
                code: a['code'] as String,
                answer: a['answer'] as String,
                comment: (a['comment'] as String?) ?? '',
              ))
          .toList();
      widget.onApply(answers);
      setState(() {
        _busy = false;
        _filled = answers.length;
        _followUp = ((data['follow_up'] as List?) ?? []).cast<String>();
      });
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
          Row(children: [
            const Icon(Icons.mic_none_rounded, color: kPrimary),
            const SizedBox(width: 8),
            Text(tr('voice_fill'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(AppLanguage.supported[AppLanguage.current.value]!, style: const TextStyle(color: Colors.grey)),
          ]),
          if (!_sttReady)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.mic_off, size: 18, color: Color(0xFFEA580C)),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('mic_unavailable'), style: const TextStyle(fontSize: 12))),
              ]),
            ),
          const SizedBox(height: 8),
          Text(tr('voice_hint'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _listening ? tr('listening') : tr('tap_to_speak'),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (_sttReady)
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: _listening ? Colors.red : kPrimary),
                onPressed: _busy ? null : _toggleMic,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kPrimary, minimumSize: const Size.fromHeight(48)),
                onPressed: _busy ? null : _fill,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_fix_high),
                label: Text(tr('fill_checklist')),
              ),
            ),
          ]),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          if (_filled != null) ...[
            const SizedBox(height: 12),
            Text(_filled == 0 ? tr('no_match') : '$_filled ${tr('filled_n')}',
                style: TextStyle(fontWeight: FontWeight.w700, color: _filled == 0 ? Colors.orange : const Color(0xFF10B981))),
            if (_followUp.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(tr('ask_next'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ..._followUp.map((q) => Text('• $q')),
            ],
          ],
        ]),
      ),
    );
  }
}
