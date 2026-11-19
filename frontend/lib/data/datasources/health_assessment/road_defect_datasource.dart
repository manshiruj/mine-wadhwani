import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mine_wadhwani/core/constants/api_constants.dart';
import 'package:mine_wadhwani/data/models/drone_analysis_result.dart';
import 'package:mine_wadhwani/data/models/road_defect_result.dart';

abstract class RoadDefectDataSource {
  Future<RoadDefectResult> analyzeImage(Uint8List imageBytes);
}

class RoadDefectRemoteDataSource implements RoadDefectDataSource {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Future<List<dynamic>> _callModel(String modelUrl, String base64Image) async {
    final response = await _dio.post(
      '$modelUrl?api_key=${ApiConstants.roboflowApiKey}',
      data: base64Image,
      options: Options(headers: {'Content-Type': 'application/x-www-form-urlencoded'}),
    );

    debugPrint('ROAD DEFECT RAW RESPONSE ($modelUrl): ${response.data}');

    final data = response.data as Map<String, dynamic>;
    return (data['predictions'] as List<dynamic>?) ?? [];
  }

  @override
  Future<RoadDefectResult> analyzeImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final potholeRaw = await _callModel(ApiConstants.potholeModelUrl, base64Image);
    final crackRaw = await _callModel(ApiConstants.crackModelUrl, base64Image);

    final potholeDetections = potholeRaw
        .map((p) => Detection.fromJson(p as Map<String, dynamic>))
        .toList();
    final crackDetections = crackRaw
        .map((p) => Detection.fromJson(p as Map<String, dynamic>))
        .toList();

    debugPrint('ROAD DEFECT: ${potholeDetections.length} potholes, ${crackDetections.length} cracks found');

    return RoadDefectResult(
      potholeDetections: potholeDetections,
      crackDetections: crackDetections,
      analyzedAt: DateTime.now(),
    );
  }
}

class MockRoadDefectDataSource implements RoadDefectDataSource {
  @override
  Future<RoadDefectResult> analyzeImage(Uint8List imageBytes) async {
    await Future.delayed(const Duration(seconds: 2));
    return RoadDefectResult(
      potholeDetections: [],
      crackDetections: [],
      analyzedAt: DateTime.now(),
    );
  }
}