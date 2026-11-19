import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mine_wadhwani/core/constants/api_constants.dart';
import 'package:mine_wadhwani/data/datasources/health_assessment/aqm_datasource.dart';
import 'package:mine_wadhwani/data/models/aqm_reading.dart';

class AqmRemoteDataSource implements AqmDataSource {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  String? _token;

  Future<String> _login() async {
    if (_token != null) return _token!;

    final response = await _dio.post(
      ApiConstants.aqiLoginUrl,
      data: {
        'email': ApiConstants.aqiEmail,
        'password': ApiConstants.aqiPassword,
      },
      options: Options(headers: {'Content-Type': 'application/x-www-form-urlencoded'}),
    );

    debugPrint('AQI LOGIN RESPONSE: ${response.data}');

    final data = response.data as Map<String, dynamic>;
    final token = data['data']?['token'] ?? data['token'];
    if (token == null) {
      throw AqmFetchException('Login succeeded but no token was returned.');
    }
    _token = token as String;
    return _token!;
  }

  double? _findSensor(List<dynamic> sensors, List<String> matchNames) {
    for (final s in sensors) {
      final name = (s['sensorname'] as String? ?? '').toLowerCase();
      for (final target in matchNames) {
        if (name.contains(target.toLowerCase())) {
          final value = s['sensorvalue'];
          if (value is num) return value.toDouble();
        }
      }
    }
    return null;
  }

  @override
  Future<AqmReading> fetchLatestReading() async {
    try {
      final token = await _login();

      final response = await _dio.get(
        ApiConstants.aqiDevicesUrl,
        options: Options(headers: {'Authorization': 'bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final devices = (data['data'] as List<dynamic>?) ?? [];

      // TEMP: print a short, readable list to find the right serial number.
      for (final d in devices) {
        debugPrint('AQI DEVICE: name="${d['devicename']}" serial="${d['serialNo']}" online=${d['isOnline']}');
      }

      final device = devices.firstWhere(
        (d) => d['serialNo'] == ApiConstants.aqmDeviceSerial,
        orElse: () => null,
      );

      if (device == null) {
        throw AqmFetchException('Device ${ApiConstants.aqmDeviceSerial} not found on this account.');
      }

      final sensors = (device['realtime'] as List<dynamic>?) ?? [];

      return AqmReading(
        pm25: _findSensor(sensors, ['pm25', 'pm2.5']) ?? 0,
        pm10: _findSensor(sensors, ['pm10']) ?? 0,
        pm1: _findSensor(sensors, ['pm1']) ?? 0,
        tvoc: _findSensor(sensors, ['tvoc']) ?? 0,
        co: _findSensor(sensors, ['co(ppm)', 'co ']) ?? 0,
        co2: _findSensor(sensors, ['co2']) ?? 0,
        h2s: _findSensor(sensors, ['h2s']) ?? 0,
        methane: _findSensor(sensors, ['ch4', 'methane']) ?? 0,
        temperature: _findSensor(sensors, ['temp(cel)', 'temperature']) ?? 0,
        humidity: _findSensor(sensors, ['hum']) ?? 0,
        noise: (_findSensor(sensors, ['noise']) ?? 0).toInt(),
        aqiUs: (_findSensor(sensors, ['aqi-us']) ?? 0).toInt(),
        fetchedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      debugPrint('AQI ERROR TYPE: ${e.type}');
      debugPrint('AQI ERROR MESSAGE: ${e.response?.data ?? e.message}');
      throw AqmFetchException('Failed to fetch AQM data: ${e.message}');
    }
  }
}