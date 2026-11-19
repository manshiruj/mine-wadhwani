import 'package:flutter_test/flutter_test.dart';
import 'package:mine_wadhwani/data/models/drone_analysis_result.dart';

Map<String, dynamic> p(String cls) =>
    {'class': cls, 'confidence': 0.8, 'x': 10, 'y': 10, 'width': 5, 'height': 5};

void main() {
  test('droneResultFromRoboflow counts PPE violations', () {
    final r = droneResultFromRoboflow({
      'image': {'width': 810, 'height': 1080},
      'predictions': [
        p('Person'), p('Person'), p('Person'),
        p('Hardhat'), p('NO-Hardhat'),
        p('Safety Vest'), p('NO-Safety Vest'), p('NO-Safety Vest'),
        p('NO-Mask'),
      ],
    });
    expect(r.workersDetected, 3);
    expect(r.workersWithPpe, 1); // 2 missing vest
    expect(r.hazardTags, [
      'Missing Helmet (1 worker)',
      'Missing Safety Vest (2 workers)',
      'Missing Mask (1 worker)',
    ]);
    expect(r.imageWidth, 810);
    expect(r.detections.length, 9);
  });

  test('no detections gives 100% compliance and no tags', () {
    final r = droneResultFromRoboflow({'predictions': []});
    expect(r.workersDetected, 0);
    expect(r.ppeCompliancePercent, 100);
    expect(r.hazardTags, isEmpty);
  });
}
