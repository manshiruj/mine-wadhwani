import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_wadhwani/core/error/exceptions.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/core/network/outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake API: returns the queued status code per call (null = network down, 0 = success).
class FakeApi extends ApiClient {
  final List<int?> script;
  final List<String> sent = [];
  FakeApi(SharedPreferences p, this.script) : super(sharedPreferences: p);

  @override
  Future<Response> post(String path, {dynamic data}) async {
    final code = script.removeAt(0);
    if (code == 0) {
      sent.add(data['id'] as String);
      return Response(requestOptions: RequestOptions(path: path), data: {'data': {'_id': 'x'}});
    }
    throw ServerException(message: 'fail', statusCode: code);
  }
}

void main() {
  test('outbox replays in order, stops when offline, parks 4xx items', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // a: offline, then a ok, b rejected (400), c ok
    final api = FakeApi(prefs, [null, 0, 400, 0]);
    final box = Outbox(prefs: prefs, api: api);
    for (final id in ['a', 'b', 'c']) {
      await box.add('/save', {'id': id});
    }
    expect(box.pending.value, 3);

    expect(await box.flush(), 0); // still offline: nothing lost
    expect(box.pending.value, 3);

    expect(await box.flush(), 2);
    expect(api.sent, ['a', 'c']);
    expect(box.pending.value, 0);
    expect(prefs.getString('outbox_failed_v1'), contains('"id":"b"')); // kept, not dropped
  });
}
