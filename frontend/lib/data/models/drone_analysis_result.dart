import 'dart:math';

class Detection {
  final String label;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  const Detection({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      label: (json['class'] as String?) ?? 'unknown',
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      x: ((json['x'] as num?) ?? 0).toDouble(),
      y: ((json['y'] as num?) ?? 0).toDouble(),
      width: ((json['width'] as num?) ?? 0).toDouble(),
      height: ((json['height'] as num?) ?? 0).toDouble(),
    );
  }
}

class DroneAnalysisResult {
  final int workersDetected;
  final int workersWithPpe;
  final List<String> hazardTags;
  final double confidenceScore;
  final DateTime analyzedAt;
  final List<Detection> detections;
  final double imageWidth;
  final double imageHeight;

  const DroneAnalysisResult({
    required this.workersDetected,
    required this.workersWithPpe,
    required this.hazardTags,
    required this.confidenceScore,
    required this.analyzedAt,
    this.detections = const [],
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  double get ppeCompliancePercent =>
      workersDetected == 0 ? 100 : (workersWithPpe / workersDetected) * 100;
}
/// Parses Roboflow Construction Site Safety output (via backend `/api/v1/drone/analyze-ppe`).
/// Classes used: Person, Hardhat, NO-Hardhat, Safety Vest, NO-Safety Vest, Mask, NO-Mask.
/// Compliance = helmet + vest (core mine PPE); missing mask is reported as a hazard tag only.
DroneAnalysisResult droneResultFromRoboflow(Map<String, dynamic> data) {
  // Workflow responses wrap the model output; plain model responses do not.
  Map<String, dynamic> block = data;
  if (data['outputs'] is List && (data['outputs'] as List).isNotEmpty) {
    final out = (data['outputs'] as List).first as Map<String, dynamic>;
    block = (out['predictions'] as Map<String, dynamic>?) ?? out;
  }
  final predictions =
      ((block['predictions'] as List?) ?? []).cast<Map<String, dynamic>>();
  final imageInfo = block['image'] as Map<String, dynamic>?;

  int count(String cls) => predictions
      .where((p) => (p['class'] as String?)?.toLowerCase() == cls)
      .length;

  final persons = count('person');
  final helmet = count('hardhat'), noHelmet = count('no-hardhat');
  final vest = count('safety vest'), noVest = count('no-safety vest');
  final noMask = count('no-mask');

  // A worker may be caught by PPE boxes without a Person box (or vice versa).
  final workers = [persons, helmet + noHelmet, vest + noVest].reduce(max);
  final nonCompliant = min(workers, max(noHelmet, noVest));

  String plural(int n) => '$n worker${n == 1 ? '' : 's'}';
  final hazardTags = <String>[
    if (noHelmet > 0) 'Missing Helmet (${plural(noHelmet)})',
    if (noVest > 0) 'Missing Safety Vest (${plural(noVest)})',
    if (noMask > 0) 'Missing Mask (${plural(noMask)})',
  ];

  final avgConfidence = predictions.isEmpty
      ? 0.0
      : predictions
              .map((p) => ((p['confidence'] as num?) ?? 0).toDouble())
              .reduce((a, b) => a + b) /
          predictions.length;

  return DroneAnalysisResult(
    workersDetected: workers,
    workersWithPpe: workers - nonCompliant,
    hazardTags: hazardTags,
    confidenceScore: avgConfidence,
    analyzedAt: DateTime.now(),
    detections: predictions.map(Detection.fromJson).toList(),
    imageWidth: ((imageInfo?['width'] as num?) ?? 0).toDouble(),
    imageHeight: ((imageInfo?['height'] as num?) ?? 0).toDouble(),
  );
}
