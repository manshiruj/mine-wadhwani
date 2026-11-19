import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline queue: POSTs that failed for lack of network are stored on the device and
/// replayed in order when connectivity returns. Item: {path, data, images?: {questionIndex: [filePaths]}}.
class Outbox {
  static const _key = 'outbox_v1';
  static const _failedKey = 'outbox_failed_v1'; // rejected by server (4xx): kept, never silently dropped

  final SharedPreferences _prefs;
  final ApiClient _api;
  final ValueNotifier<int> pending = ValueNotifier(0);
  bool _flushing = false;
  StreamSubscription? _sub;

  Outbox({required SharedPreferences prefs, required ApiClient api})
      : _prefs = prefs,
        _api = api {
    pending.value = _items().length;
  }

  List<Map<String, dynamic>> _items([String key = _key]) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _save(List<Map<String, dynamic>> items, [String key = _key]) async {
    await _prefs.setString(key, jsonEncode(items));
    if (key == _key) pending.value = items.length;
  }

  Future<void> add(String path, Map<String, dynamic> data,
      {Map<int, List<String>> images = const {}}) async {
    final items = _items()
      ..add({
        'path': path,
        'data': data,
        'images': images.map((k, v) => MapEntry('$k', v)),
        'queuedAt': DateTime.now().toIso8601String(),
      });
    await _save(items);
  }

  /// Replays queued items. Stops at the first network failure (still offline).
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      var items = _items();
      while (items.isNotEmpty) {
        final item = items.first;
        try {
          final res = await _api.post(item['path'] as String, data: item['data']);
          await _uploadImages(res, item);
          sent++;
        } on ServerException catch (e) {
          if (e.statusCode == null || e.statusCode! >= 500) break; // offline / server down: retry later
          final failed = _items(_failedKey)..add({...item, 'error': e.message});
          await _save(failed, _failedKey);
        }
        items = items.sublist(1);
        await _save(items);
      }
    } finally {
      _flushing = false;
    }
    if (sent > 0) debugPrint('OUTBOX: synced $sent item(s)');
    return sent;
  }

  Future<void> _uploadImages(Response res, Map<String, dynamic> item) async {
    final images = (item['images'] as Map?)?.cast<String, dynamic>() ?? {};
    if (images.isEmpty || kIsWeb) return; // web has no persistent file paths
    final id = ((res.data as Map)['data'] as Map?)?['_id'] as String?;
    if (id == null) return;
    for (final e in images.entries) {
      try {
        final form = FormData();
        for (final p in (e.value as List).cast<String>()) {
          form.files.add(MapEntry('images', await MultipartFile.fromFile(p)));
        }
        await _api.multipartPost('/api/v1/forms-data/upload-media/$id/${e.key}', data: form);
      } catch (err) {
        debugPrint('OUTBOX: image upload for question ${e.key} failed: $err');
      }
    }
  }

  /// Flush now and whenever the device comes back online.
  void start() {
    flush();
    _sub ??= Connectivity().onConnectivityChanged.listen((r) {
      if (!r.contains(ConnectivityResult.none)) flush();
    });
  }
}
