// Renders every screen at phone & tablet sizes and fails on layout overflow ("RenderFlex overflowed").
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_wadhwani/core/di/injection_container.dart' as di;
import 'package:mine_wadhwani/core/l10n/app_language.dart';
import 'package:mine_wadhwani/presentation/bloc/auth_bloc/auth_bloc.dart';
import 'package:mine_wadhwani/presentation/bloc/draft_bloc/draft_bloc.dart';
import 'package:mine_wadhwani/presentation/bloc/checklist_bloc/checklist_bloc.dart';
import 'package:mine_wadhwani/presentation/screens/agent/actions_screen.dart';
import 'package:mine_wadhwani/presentation/screens/agent/chat_screen.dart';
import 'package:mine_wadhwani/presentation/screens/agent/agents_hub_screen.dart';
import 'package:mine_wadhwani/presentation/screens/agent/risk_monitor_screen.dart';
import 'package:mine_wadhwani/presentation/screens/agent/dashboard_screen.dart';
import 'package:mine_wadhwani/presentation/screens/agent/handover_screen.dart';
import 'package:mine_wadhwani/presentation/screens/auth/login_page.dart';
import 'package:mine_wadhwani/presentation/screens/auth/signup_page.dart';
import 'package:mine_wadhwani/presentation/screens/common/inspection_checklist_page.dart';
import 'package:mine_wadhwani/presentation/screens/common/inspection_compliance_page.dart';
import 'package:mine_wadhwani/presentation/screens/common/inspection_report_preview_page.dart';
import 'package:mine_wadhwani/presentation/screens/datacollection/mine_info_page.dart';
import 'package:mine_wadhwani/presentation/screens/datacollection/mine_selection.dart';
import 'package:mine_wadhwani/presentation/screens/datacollection/shift_selection.dart';
import 'package:mine_wadhwani/presentation/screens/haul_road/haul_road_data.dart';
import 'package:mine_wadhwani/presentation/screens/haul_road/haul_road_overview_page.dart';
import 'package:mine_wadhwani/presentation/screens/hazard_database/hazard_database_page.dart';
import 'package:mine_wadhwani/presentation/screens/health_assessment/health_assessment_prompt_page.dart';
import 'package:mine_wadhwani/presentation/screens/health_assessment/risk_summary_sheet.dart';
import 'package:mine_wadhwani/presentation/screens/home/home_page.dart';
import 'package:mine_wadhwani/presentation/screens/notifications/notification_screen.dart';
import 'package:mine_wadhwani/presentation/screens/pending_inspections/pending_inspections_screen.dart';
import 'package:mine_wadhwani/presentation/screens/profile/profile_screen.dart';
import 'package:mine_wadhwani/presentation/screens/risk_analysis/risk_analysis_screen.dart';
import 'package:mine_wadhwani/presentation/screens/stockpile/action_page.dart';
import 'package:mine_wadhwani/presentation/screens/stockpile/stockpile_checklist_page.dart';
import 'package:mine_wadhwani/presentation/screens/stockpile/stockpile_compliance_page.dart';
import 'package:mine_wadhwani/presentation/screens/stockpile/stockpile_data.dart';
import 'package:mine_wadhwani/presentation/screens/stockpile/stockpile_overview_page.dart';
import 'package:mine_wadhwani/presentation/screens/stockpile/stockpile_report_preview_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1x1 transparent PNG (report pages decode the signature image).
final _png1x1 = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 11, 73, 68, 65, 84, 120, 156, 99, 96, 0, 2, 0, 0, 5, 0, 1, 122, 94, 171, 63, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);

const sizes = {
  'phone portrait 360x740': Size(360, 740),
  'phone landscape 740x360': Size(740, 360),
  'tablet portrait 800x1280': Size(800, 1280),
};

final hrAnswers = {
  for (final s in HaulRoadData.sections)
    for (final q in s.questions) q.code: q.code.hashCode.isEven ? 'YES' : 'NO'
};
final hrComments = {for (final k in hrAnswers.keys) k: 'Observed issue near km 2 bench, needs repair'};
final spAnswers = {
  for (final s in StockpileData.sections)
    for (final q in s.questions) q.code: q.code.hashCode.isEven ? 'YES' : 'NO'
};

Map<String, Widget Function()> screens() => {
      'Login': () => const LoginPage(),
      'Signup': () => const SignupPage(),
      'Home': () => const HomePage(),
      'Profile': () => const ProfileScreen(name: 'Rishu Kumar Sharma', role: 'Shift Supervisor', email: 'supervisor@example.com', phone: '9999999999'),
      'Mine selection': () => const MineSelectionPage(),
      'Mine info': () => const MineInfoPage(mineName: 'Jharia Opencast Project', mineType: 'Opencast', company: 'Coal India', subsidiary: 'BCCL'),
      'Shift selection': () => const ShiftSelectionPage(mineName: 'Jharia Opencast Project', mineType: 'Opencast', area: 'Haul Road', company: 'Coal India'),
      'Health assessment': () => const HealthAssessmentPromptPage(mineName: 'Jharia', area: 'Haul Road', shift: 1, inspectionType: 'Haul Road'),
      'Risk summary': () => const RiskSummarySheet(flagCount: 2, totalChecks: 5, flagDetails: ['PM2.5 above limit', 'PPE compliance 60%']),
      'Haul road overview': () => const HaulRoadOverviewPage(mineName: 'Jharia', mineType: 'Opencast', area: 'Haul Road', shift: 1, inspectionType: 'Haul Road', company: 'Coal India'),
      'Haul road checklist': () => InspectionChecklistPage(sectionIndex: 0, sections: HaulRoadData.sections, answers: hrAnswers, comments: hrComments, mediaFiles: const {}, actions: const {}, mineName: 'Jharia', mineType: 'Opencast', area: 'Haul Road', shift: 1, inspectionType: 'Haul Road'),
      'Haul road compliance': () => InspectionCompliancePage(company: 'Coal India', mineName: 'Jharia', mineType: 'Opencast', area: 'Haul Road', shift: 1, inspectionType: 'Haul Road', sections: HaulRoadData.sections, answers: hrAnswers, comments: hrComments, mediaFiles: const {}, actions: const {}, inspectorName: 'Rishu', inspectorRole: 'Supervisor'),
      'Haul road report': () => InspectionReportPreviewPage(company: 'Coal India', mineName: 'Jharia', mineType: 'Opencast', area: 'Haul Road', shift: 1, inspectionType: 'Haul Road', sections: HaulRoadData.sections, answers: hrAnswers, comments: hrComments, mediaFiles: const {}, actions: const {}, inspectorName: 'Rishu', inspectorRole: 'Supervisor', observations: 'Dust heavy near pit exit', signatureBytes: _png1x1, reviewedAt: DateTime(2026, 11, 10)),
      'Stockpile overview': () => const StockpileOverviewPage(mineName: 'Jharia', mineType: 'Opencast', area: 'Stockpile', shift: 1, inspectionType: 'Stockpile', company: 'Coal India'),
      'Stockpile checklist': () => StockpileChecklistPage(sectionIndex: 0, sections: StockpileData.sections, answers: spAnswers, comments: const {}, mediaFiles: const {}, actions: const {}, mineName: 'Jharia', mineType: 'Opencast', area: 'Stockpile', shift: 1, inspectionType: 'Stockpile'),
      'Stockpile compliance': () => StockpileCompliancePage(company: 'Coal India', mineName: 'Jharia', mineType: 'Opencast', area: 'Stockpile', shift: 1, inspectionType: 'Stockpile', sections: StockpileData.sections, answers: spAnswers, comments: const {}, mediaFiles: const {}, actions: const {}, inspectorName: 'Rishu', inspectorRole: 'Supervisor'),
      'Stockpile report': () => StockpileReportPreviewPage(company: 'Coal India', mineName: 'Jharia', mineType: 'Opencast', area: 'Stockpile', shift: 1, inspectionType: 'Stockpile', sections: StockpileData.sections, answers: spAnswers, comments: const {}, mediaFiles: const {}, actions: const {}, inspectorName: 'Rishu', inspectorRole: 'Supervisor', observations: 'ok', signatureBytes: _png1x1, reviewedAt: DateTime(2026, 11, 10)),
      'Action page': () => const ActionPage(questionCode: 'Q2.1', questionText: 'Is the longitudinal gradient of the haul road maintained within the permissible 1 in 16 limit?'),
      'Pending inspections': () => const PendingInspectionsScreen(),
      'Risk analysis': () => const RiskAnalysisScreen(),
      'Hazard database': () => const HazardDatabasePage(),
      'Alerts': () => const NotificationScreen(),
      'Handover': () => const HandoverScreen(),
      'Actions': () => const ActionsScreen(),
      'Dashboard': () => const DashboardScreen(),
      'Chat': () => const ChatScreen(),
      'Agents hub': () => const AgentsHubScreen(),
      'Risk monitor': () => const RiskMonitorScreen(),
    };

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await di.init();
    // --dart-define=LANG=hi runs every screen in Hindi (longer labels).
    AppLanguage.current.value = const String.fromEnvironment('LANG', defaultValue: 'en');
  });

  final only = const String.fromEnvironment('SCREEN');
  for (final entry in screens().entries) {
    if (only.isNotEmpty && !entry.key.toLowerCase().contains(only.toLowerCase())) continue;
    for (final size in sizes.entries) {
      // Known pre-existing bug: assets/json/hazard_database.json is missing from the repo.
      final skip = entry.key == 'Hazard database' ? true : null;
      testWidgets('${entry.key} @ ${size.key}', skip: skip, (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final overflows = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          final s = d.exceptionAsString();
          if (s.contains('overflowed')) {
            final where = RegExp(r'lib/presentation/[\w/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
            overflows.add('${s.split('\n').first.trim()} @ $where');
          } else if (!s.contains('MissingPluginException')) {
            prev?.call(d); // real errors fail the test (platform plugins are absent in tests)
          }
        };
        await tester.pumpWidget(MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => di.sl<AuthBloc>()),
            BlocProvider(create: (_) => di.sl<DraftBloc>()),
            BlocProvider(create: (_) => di.sl<ChecklistBloc>()),
          ],
          child: MaterialApp(home: entry.value()),
        ));
        await tester.pump(const Duration(milliseconds: 500));
        // Let real async work (asset loading) finish, then lay out with the data.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump(const Duration(milliseconds: 500));
        FlutterError.onError = prev;
        // Let screen animations/timers finish so they don't fail the test.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
        expect(overflows, isEmpty, reason: overflows.toSet().join('\n'));
      });
    }
  }
}
