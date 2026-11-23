import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart' as di;
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/presentation/screens/risk_analysis/risk_analysis_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns a backend-shaped /risk-monitor/assess result instead of calling the server.
class FakeAssessApi extends ApiClient {
  final sent = <Map<String, dynamic>>[];
  FakeAssessApi(SharedPreferences p) : super(sharedPreferences: p);

  @override
  Future<Response> post(String path, {dynamic data}) async {
    sent.add(Map<String, dynamic>.from(data as Map));
    return Response(requestOptions: RequestOptions(path: path), data: {
      'data': {
        'grade': 3,
        'level': 'High',
        'risk_index': 52,
        'measured': {'coal_temp_c': 105, 'co_ppm': 140, 'o2_pct': 19},
        'ml': {
          'grade': 2,
          'confidence': 0.61,
          'expected_grade': 2.6,
          'baseline_grade': 1.4,
          'probabilities': {'0': 0.05, '1': 0.1, '2': 0.61, '3': 0.2, '4': 0.04, '5': 0},
          'contributions': {'coal_temp_c': 0.92, 'log_co': 0.41, 'graham': -0.12, 'o2_deficit': 0.05},
          'model': {'name': 'heating', 'version': '1'},
        },
        'safety_alerts': [{'message': 'Coal temperature 105 °C is in hazard grade 3 band (≥ 100 °C).'}],
        'data_quality': ['C2H4 not measured: advanced-stage (pyrolysis) signal unavailable.'],
        'explanation': {
          'summary': 'The stockpile coal is at 105 °C with CO at 140 ppm, which places it in the High heating band. '
              'Inspect the hot spot this shift and confirm with a probe reading before any further handling.',
          'active_safety_alerts': ['Coal temperature 105 °C is in hazard grade 3 band (≥ 100 °C).', 'CO 140 ppm ≥ site high action level 100 ppm.'],
          'recommended_actions': [{'procedure_id': 'SP-1', 'action': 'Probe the pile', 'priority': 'immediate'}],
          'data_quality_warnings': ['C2H4 not measured'],
          'human_review_required': true,
        },
        'createdAt': '2026-11-23T10:00:00Z',
      }
    });
  }
}

late FakeAssessApi api;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await di.init();
    di.sl.allowReassignment = true;
    api = FakeAssessApi(di.sl<SharedPreferences>());
    di.sl.registerSingleton<ApiClient>(api);
  });

  const sizes = {'phone': Size(360, 740), 'phone landscape': Size(740, 360), 'tablet': Size(800, 1280), 'tablet landscape': Size(1280, 800)};
  for (final lang in ['en', 'hi']) {
    for (final s in sizes.entries) {
      testWidgets('Analyse Risk shows the model result ($lang, ${s.key})', (t) async {
        AppLanguage.current.value = lang;
        t.view.physicalSize = s.value;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final overflows = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exceptionAsString().contains('overflowed')) {
            overflows.add(d.exceptionAsString().split('\n').first);
          } else {
            prev?.call(d);
          }
        };
        api.sent.clear();
        await t.pumpWidget(const MaterialApp(home: RiskAnalysisScreen()));
        final button = find.text(tr('Analyse Risk'));
        await t.ensureVisible(button);
        await t.pumpAndSettle();
        await t.tap(button);
        await t.pumpAndSettle();
        FlutterError.onError = prev;

        expect(api.sent.single['co_ppm'], '20');
        expect(api.sent.single.containsKey('humidity_pct'), isFalse);
        expect(find.textContaining('105 °C with CO'), findsOneWidget); // result card shows the AI summary
        expect(find.text(tr('High')), findsWidgets); // final level (also a gauge zone label)
        expect(find.textContaining('52 / 100'), findsOneWidget);
        expect(find.text(tr('coal_temp')), findsWidgets); // contributions use the model's factors
        expect(overflows, isEmpty, reason: overflows.join('\n'));
      });
    }
  }
}
