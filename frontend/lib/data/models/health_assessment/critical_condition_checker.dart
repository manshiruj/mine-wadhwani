import 'package:mine_wadhwani/data/models/health_assessment/health_assessment_model.dart';
import 'package:mine_wadhwani/data/models/health_assessment/risk_index_calculator.dart';

class CriticalAlert {
  final String reason; // human-readable, used for the TTS message and screen
  final String zone;

  const CriticalAlert({required this.reason, required this.zone});
}

class CriticalConditionChecker {
  /// Returns a CriticalAlert if either the Risk Index is in the Critical
  /// band, or any single reading crosses a stricter critical threshold.
  /// Returns null if nothing critical was found.
  static CriticalAlert? check(HealthAssessmentModel ha) {
    // Check 1: individual stricter thresholds — catches a single dangerous
    // spike even if other categories keep the composite score moderate.
    final co = double.tryParse(ha.aqmReadings['CO (ppm)'] ?? '');
    if (co != null && co > HealthThresholds.criticalMaxCo) {
      return CriticalAlert(reason: 'Critical carbon monoxide level: ${co.toStringAsFixed(0)} ppm', zone: ha.zone);
    }

    final h2s = double.tryParse(ha.aqmReadings['H2S (ppm)'] ?? '');
    if (h2s != null && h2s > HealthThresholds.criticalMaxH2s) {
      return CriticalAlert(reason: 'Critical hydrogen sulfide level: ${h2s.toStringAsFixed(1)} ppm', zone: ha.zone);
    }

    final methane = double.tryParse(ha.aqmReadings['Methane (%)'] ?? '');
    if (methane != null && methane > HealthThresholds.criticalMaxMethane) {
      return CriticalAlert(reason: 'Critical methane level: ${methane.toStringAsFixed(2)} percent', zone: ha.zone);
    }

    for (final w in ha.workerReadings) {
      final hr = double.tryParse(w.heartRate);
      if (hr != null && (hr < HealthThresholds.criticalMinHeartRate || hr > HealthThresholds.criticalMaxHeartRate)) {
        final name = w.name.isEmpty ? 'A worker' : w.name;
        return CriticalAlert(reason: '$name has a critical heart rate: ${hr.toStringAsFixed(0)} beats per minute', zone: ha.zone);
      }
      final spo2 = double.tryParse(w.spo2);
      if (spo2 != null && spo2 < HealthThresholds.criticalMinSpo2) {
        final name = w.name.isEmpty ? 'A worker' : w.name;
        return CriticalAlert(reason: '$name has critically low oxygen saturation: ${spo2.toStringAsFixed(0)} percent', zone: ha.zone);
      }
    }

    // Check 2: composite Risk Index in the Critical band.
    final riskIndex = RiskIndexCalculator.calculate(ha);
    if (riskIndex.band == RiskBand.critical) {
      final worst = riskIndex.worstCategory;
      final detail = worst != null ? '${worst.name}: ${worst.detail}' : 'multiple factors';
      return CriticalAlert(
        reason: 'Critical risk index, ${riskIndex.overallScore.toStringAsFixed(0)} out of 100. Driven by $detail',
        zone: ha.zone,
      );
    }

    return null;
  }
}