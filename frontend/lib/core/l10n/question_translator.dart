import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart';
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Batches checklist texts, translates them via backend `/api/v1/ai/translate`,
/// and caches results on the device so each text is fetched once per language.
class QuestionTranslator extends ChangeNotifier {
  QuestionTranslator._();
  static final QuestionTranslator instance = QuestionTranslator._();

  final Map<String, Map<String, String>> _cache = {}; // lang -> text -> translated
  final Set<String> _queued = {};
  final Set<String> _failed = {};
  Timer? _debounce;

  String _prefsKey(String lang) => 'tr_cache_$lang';

  Map<String, String> _langCache(String lang) => _cache.putIfAbsent(lang, () {
        final raw = sl<SharedPreferences>().getString(_prefsKey(lang));
        if (raw == null) return {};
        try {
          return Map<String, String>.from(jsonDecode(raw) as Map);
        } catch (_) {
          return {};
        }
      });

  /// Returns the translation if known; otherwise schedules a fetch and returns null.
  String? lookup(String text) {
    final lang = AppLanguage.current.value;
    if (lang == 'en' || text.isEmpty) return text;
    final hit = _langCache(lang)[text];
    if (hit != null) return hit;
    if (!_failed.contains('$lang|$text') && _queued.add(text)) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), _flush);
    }
    return null;
  }

  Future<void> _flush() async {
    final lang = AppLanguage.current.value;
    final batch = _queued.toList();
    _queued.clear();
    if (batch.isEmpty || lang == 'en') return;
    try {
      final res = await sl<ApiClient>().post('/api/v1/ai/translate',
          data: {'texts': batch, 'language': lang});
      final map = ((res.data as Map)['data'] as Map)['translations'] as Map;
      final cache = _langCache(lang);
      map.forEach((k, v) {
        if (v != k) cache[k as String] = v as String; // untranslated (AI off) -> retry later
      });
      for (final t in batch) {
        if (!cache.containsKey(t)) _failed.add('$lang|$t');
      }
      await sl<SharedPreferences>().setString(_prefsKey(lang), jsonEncode(cache));
      notifyListeners();
    } catch (_) {
      _failed.addAll(batch.map((t) => '$lang|$t')); // offline etc.: show English, no retry storm
    }
  }
}

/// Drop-in for `Text(question.text, ...)`: shows the translation (and English below) when a language is chosen.
class TrText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TrText(this.text,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppLanguage.current, QuestionTranslator.instance]),
      builder: (context, _) {
        final translated = QuestionTranslator.instance.lookup(text);
        if (translated == null || translated == text) {
          return Text(text,
              style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(translated,
                style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow),
            const SizedBox(height: 4),
            Text(text,
                style: (style ?? const TextStyle()).copyWith(
                    fontSize: ((style?.fontSize) ?? 14) - 2,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400),
                textAlign: textAlign),
          ],
        );
      },
    );
  }
}
