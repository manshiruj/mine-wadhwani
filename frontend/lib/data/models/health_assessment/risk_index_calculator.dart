import 'package:mine_wadhwani/data/models/health_assessment/health_assessment_model.dart';

enum RiskBand { low, moderate, high, critical }

extension RiskBandX on RiskBand {
  String get label {
    switch (this) {
      case RiskBand.low:
        return 'Low Risk';
      case RiskBand.moderate:
        return 'Moderate Risk';
      case RiskBand.high:
        return 'High Risk';
      case RiskBand.critical:
        return 'Critical Risk';
    }
  }
}

class RiskCategoryScore {
  final String name;
  final double score; // 0-100, 100 = safest
  final String detail;

  const RiskCategoryScore({
    required this.name,
    required this.score,
    required this.detail,
  });
}

class RiskIndexResult {
  final double overallScore; // 0-100
  final RiskBand band;
  final List<RiskCategoryScore> categories;

  const RiskIndexResult({
    required this.overallScore,
    required this.band,
    required this.categories,
  });

  /// The category with the lowest (worst) score — used to explain
  /// "why" the index is high, e.g. for the TTS announcement.
  RiskCategoryScore? get worstCategory {
    if (categories.isEmpty) return null;
    return categories.reduce((a, b) => a.score < b.score ? a : b);
  }
}

class RiskIndexCalculator {
  static RiskIndexResult calculate(HealthAssessmentModel ha) {
    final categories = <RiskCategoryScore>[];
    final weights = <String, double>{};

    if (ha.modes.contains('AQM') && ha.aqmReadings.isNotEmpty) {
      final result = _airQualityScore(ha);
      categories.add(result);
      weights[result.name] = 0.35;
    }

    if (ha.modes.contains('Drone') && ha.droneReadings.isNotEmpty) {
      final ppeResult = _ppeScore(ha);
      categories.add(ppeResult);
      weights[ppeResult.name] = 0.30;

      final hazardResult = _hazardScore(ha);
      categories.add(hazardResult);
      weights[hazardResult.name] = 0.15;
    }

    if (ha.modes.contains('Smartwatch') && ha.workerReadings.isNotEmpty) {
      final result = _vitalsScore(ha);
      categories.add(result);
      weights[result.name] = 0.20;
    }

    if (categories.isEmpty) {
      return const RiskIndexResult(
        overallScore: 100,
        band: RiskBand.low,
        categories: [],
      );
    }

    // Redistribute weights proportionally across categories actually present.
    final totalWeight = weights.values.fold(0.0, (a, b) => a + b);
    double overall = 0;
    for (final c in categories) {
      final normalizedWeight = weights[c.name]! / totalWeight;
      overall += c.score * normalizedWeight;
    }

    return RiskIndexResult(
      overallScore: overall,
      band: _bandFor(overall),
      categories: categories,
    );
  }

  static RiskBand _bandFor(double score) {
    if (score >= 80) return RiskBand.low;
    if (score >= 60) return RiskBand.moderate;
    if (score >= 40) return RiskBand.high;
    return RiskBand.critical;
  }

  static RiskCategoryScore _airQualityScore(HealthAssessmentModel ha) {
    final checks = <MapEntry<String, double>>[
      _severityFor(ha.aqmReadings['PM2.5 (µg/m³)'], HealthThresholds.maxPm25),
      _severityFor(ha.aqmReadings['CO (ppm)'], HealthThresholds.maxCo),
      _severityFor(ha.aqmReadings['CO2 (ppm)'], HealthThresholds.maxCo2),
      _severityFor(ha.aqmReadings['H2S (ppm)'], HealthThresholds.maxH2s),
      _severityFor(ha.aqmReadings['Methane (%)'], HealthThresholds.maxMethane),
      _severityFor(ha.aqmReadings['Temperature (°C)'], HealthThresholds.maxTemperature),
      _severityFor(ha.aqmReadings['Noise (dB)'], HealthThresholds.maxNoise),
    ].where((e) => e.value >= 0).toList();

    if (checks.isEmpty) {
      return const RiskCategoryScore(name: 'Air Quality', score: 100, detail: 'No readings');
    }

    final avgSeverity = checks.map((e) => e.value).reduce((a, b) => a + b) / checks.length;
    final score = (100 - (avgSeverity * 100)).clamp(0, 100).toDouble();

    final worst = checks.reduce((a, b) => a.value > b.value ? a : b);
    final detail = worst.value > 0
        ? '${worst.key} above safe limit'
        : 'All readings within safe limits';

    return RiskCategoryScore(name: 'Air Quality', score: score, detail: detail);
  }

  /// Returns severity as (fieldName -> fraction over limit, 0 if within limit).
  /// Returns value -1 if the field wasn't recorded, so it can be filtered out.
  static MapEntry<String, double> _severityFor(String? rawValue, double threshold) {
    if (rawValue == null || rawValue.trim().isEmpty) return const MapEntry('', -1);
    final value = double.tryParse(rawValue);
    if (value == null) return const MapEntry('', -1);
    final severity = value > threshold ? (value - threshold) / threshold : 0.0;
    return MapEntry(rawValue, severity);
  }

  static RiskCategoryScore _ppeScore(HealthAssessmentModel ha) {
    final ppe = double.tryParse(ha.droneReadings['PPE Compliance (%)'] ?? '') ?? 100;
    return RiskCategoryScore(
      name: 'PPE Compliance',
      score: ppe.clamp(0, 100),
      detail: '${ppe.toStringAsFixed(0)}% compliant',
    );
  }

  static RiskCategoryScore _hazardScore(HealthAssessmentModel ha) {
    final hazards = (ha.droneReadings['Hazard Tags'] ?? '').trim();
    if (hazards.isEmpty) {
      return const RiskCategoryScore(name: 'Hazard Presence', score: 100, detail: 'No hazards detected');
    }
    final count = hazards.split(',').length;
    final score = (100 - (count * 30)).clamp(20, 100).toDouble();
    return RiskCategoryScore(name: 'Hazard Presence', score: score, detail: hazards);
  }

  static RiskCategoryScore _vitalsScore(HealthAssessmentModel ha) {
    if (ha.workerReadings.isEmpty) {
      return const RiskCategoryScore(name: 'Worker Vitals', score: 100, detail: 'No workers checked');
    }
    final flagged = ha.workerReadings.where((w) => w.isFlagged).length;
    final score = (100 - (flagged / ha.workerReadings.length * 100)).clamp(0, 100).toDouble();
    final detail = flagged == 0
        ? 'All workers within safe range'
        : '$flagged of ${ha.workerReadings.length} worker(s) flagged';
    return RiskCategoryScore(name: 'Worker Vitals', score: score, detail: detail);
  }
}