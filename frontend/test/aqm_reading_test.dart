import 'package:flutter_test/flutter_test.dart';
import 'package:mine_wadhwani/data/models/aqm_reading.dart';

void main() {
  test('AqmReading.fromAqiIn maps aqi.in sensor names', () {
    final r = AqmReading.fromAqiIn({
      'devicename': 'Pit-1',
      'sensors': {
        'PM25': {'value': 160, 'unit': 'µg/m³'},
        'CO2(ppm)': {'value': 946, 'unit': 'ppm'},
        'CO(ppm)': {'value': 1.5, 'unit': 'ppm'},
        'Temp(cel)': {'value': 24, 'unit': '°C'},
        'Temp(Fer)': {'value': 75, 'unit': '°F'},
        'Hum': {'value': 71, 'unit': '%'},
        'AQI-US': {'value': 210, 'unit': null},
      },
    });
    expect(r.pm25, 160);
    expect(r.co2, 946);
    expect(r.co, 1.5);
    expect(r.temperature, 24); // Celsius must win over Fahrenheit
    expect(r.humidity, 71);
    expect(r.aqiUs, 210);
    expect(r.h2s, isNull);
    expect(r.deviceName, 'Pit-1');
  });
}
