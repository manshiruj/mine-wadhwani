import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_wadhwani/core/constants/app_constants.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart' as di;
import 'package:mine_wadhwani/core/network/api_client.dart';
import 'package:mine_wadhwani/data/models/draft/inspection_draft_model.dart';
import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_bloc.dart';
import 'package:mine_wadhwani/presentation/bloc/draft_bloc/draft_bloc.dart';
import 'package:mine_wadhwani/presentation/screens/common/inspection_checklist_page.dart';
import 'package:mine_wadhwani/presentation/screens/haul_road/haul_road_data.dart';
import 'package:mine_wadhwani/presentation/screens/haul_road/haul_road_overview_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records draft saves instead of calling the server.
class RecordingApi extends ApiClient {
  final List<Map<String, dynamic>> saves = [];
  RecordingApi(SharedPreferences p) : super(sharedPreferences: p);

  @override
  Future<Response> post(String path, {dynamic data}) async {
    if (path.endsWith('/save-data')) saves.add(Map<String, dynamic>.from(data as Map));
    return Response(requestOptions: RequestOptions(path: path), data: {'data': {'_id': 'x'}});
  }

  @override
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async =>
      Response(requestOptions: RequestOptions(path: path), data: {'data': []});
}

late RecordingApi api;

Widget app(Widget home) => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider(create: (_) => di.sl<DraftBloc>()),
      ],
      child: MaterialApp(home: home),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.userKey: jsonEncode({'_id': 'u1', 'name': 'T', 'email': 't@x', 'mobilenumber': '1'}),
    });
    await di.init();
    di.sl.allowReassignment = true;
    api = RecordingApi(di.sl<SharedPreferences>());
    di.sl.registerSingleton<ApiClient>(api);
  });

  testWidgets('leaving an inspection with answers auto-saves it as a draft', (t) async {
    api.saves.clear();
    final draft = InspectionDraft(
      id: 'local1', mineName: 'M', mineType: 'Opencast', area: 'Haul Road', shift: 1,
      inspectionType: 'Haul Road', savedAt: DateTime(2026), answeredCount: 1, totalCount: 23,
      answers: const [{'code': 'Q1.1', 'answer': 'YES', 'section': 'S'}],
    );
    await t.pumpWidget(app(HaulRoadOverviewPage(
        mineName: 'M', mineType: 'Opencast', area: 'Haul Road', shift: 1,
        inspectionType: 'Haul Road', company: 'C', draft: draft)));
    await t.pump();
    await t.pumpWidget(const SizedBox()); // page closed (back press / app killed)
    await t.pump(const Duration(milliseconds: 50));
    expect(api.saves, hasLength(1));
    expect(api.saves.first['completed'], false);
    final q11 = (api.saves.first['checklistData'] as List).firstWhere((q) => q['questionCode'] == 'Q1.1');
    expect(q11['answer'], 'YES');
  });

  testWidgets('empty inspection is not saved', (t) async {
    api.saves.clear();
    await t.pumpWidget(app(const HaulRoadOverviewPage(
        mineName: 'M', mineType: 'Opencast', area: 'Haul Road', shift: 1, inspectionType: 'Haul Road', company: 'C')));
    await t.pump();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 50));
    expect(api.saves, isEmpty);
  });

  testWidgets('checklist page reports answers when it closes', (t) async {
    Map<String, String>? reported;
    await t.pumpWidget(MaterialApp(
        home: InspectionChecklistPage(
            sectionIndex: 0, sections: HaulRoadData.sections, answers: const {'Q1.1': 'NO'},
            comments: const {}, mediaFiles: const {}, actions: const {}, mineName: 'M', mineType: 'O',
            area: 'H', shift: 1, inspectionType: 'Haul Road', onProgress: (r) => reported = r)));
    await t.pumpWidget(const SizedBox());
    expect(reported?['a:Q1.1'], 'NO');
  });
}
