import 'dart:convert';
import 'package:http/http.dart' as http;

class HourlyWeather {
  final String time;
  final double tempC;
  final String conditionIconUrl;
  final int chanceOfRain;

  HourlyWeather({
    required this.time,
    required this.tempC,
    required this.conditionIconUrl,
    required this.chanceOfRain,
  });
}

class DailyForecast {
  final String date;
  final double maxTempC;
  final double minTempC;
  final String conditionIconUrl;
  final String conditionText;

  DailyForecast({
    required this.date,
    required this.maxTempC,
    required this.minTempC,
    required this.conditionIconUrl,
    required this.conditionText,
  });
}

class WeatherData {
  final String conditionText;
  final String conditionIconUrl;
  final double tempC;
  final double feelsLikeC;
  final int humidity;
  final double windKph;
  final String locationName;
  final List<HourlyWeather> hourlyForecast;
  final List<DailyForecast> dailyForecast;

  WeatherData({
    required this.conditionText,
    required this.conditionIconUrl,
    required this.tempC,
    required this.feelsLikeC,
    required this.humidity,
    required this.windKph,
    required this.locationName,
    required this.hourlyForecast,
    required this.dailyForecast,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final location = json['location'];
    
    List<HourlyWeather> hourlyList = [];
    List<DailyForecast> dailyList = [];
    
    if (json['forecast'] != null && json['forecast']['forecastday'] != null) {
      final forecastDays = json['forecast']['forecastday'] as List;
      
      // Daily 파싱
      for (var day in forecastDays) {
        dailyList.add(DailyForecast(
          date: day['date'] ?? '',
          maxTempC: day['day']['maxtemp_c']?.toDouble() ?? 0.0,
          minTempC: day['day']['mintemp_c']?.toDouble() ?? 0.0,
          conditionIconUrl: 'https:' + day['day']['condition']['icon'],
          conditionText: day['day']['condition']['text'] ?? '',
        ));
      }
      
      // Hourly 파싱 (현재 시간 이후 24시간 정도를 뽑기 위해 첫째 날과 둘째 날 시간 데이터를 병합)
      if (forecastDays.isNotEmpty) {
        final List hoursDay1 = forecastDays[0]['hour'] ?? [];
        final List hoursDay2 = forecastDays.length > 1 ? forecastDays[1]['hour'] ?? [] : [];
        
        final allHours = [...hoursDay1, ...hoursDay2];
        final now = DateTime.now();
        
        for (var hour in allHours) {
          final timeStr = hour['time']; // "2023-10-01 12:00"
          final hourDateTime = DateTime.tryParse(timeStr);
          if (hourDateTime != null && hourDateTime.isAfter(now.subtract(const Duration(hours: 1)))) {
            hourlyList.add(HourlyWeather(
              time: '${hourDateTime.hour.toString().padLeft(2, '0')}:00',
              tempC: hour['temp_c']?.toDouble() ?? 0.0,
              conditionIconUrl: 'https:' + hour['condition']['icon'],
              chanceOfRain: hour['chance_of_rain'] ?? 0,
            ));
            if (hourlyList.length >= 24) break; // 24시간치만
          }
        }
      }
    }
    return WeatherData(
      conditionText: current['condition']['text'],
      conditionIconUrl: 'https:' + current['condition']['icon'],
      tempC: current['temp_c']?.toDouble() ?? 0.0,
      feelsLikeC: current['feelslike_c']?.toDouble() ?? 0.0,
      humidity: current['humidity'] ?? 0,
      windKph: current['wind_kph']?.toDouble() ?? 0.0,
      locationName: location['name'] ?? '알 수 없음',
      hourlyForecast: hourlyList,
      dailyForecast: dailyList,
    );
  }
}

class WeatherService {
  static const String _apiKey = '4d9f022a86ef4a51b4770052262906'; 

  Future<WeatherData> fetchWeather(double lat, double lon) async {
    // current.json 대신 forecast.json을 사용하여 향후 일기예보 등 더 다양한 화면 구성을 지원할 수 있습니다.
    final url = Uri.parse('https://api.weatherapi.com/v1/forecast.json?key=$_apiKey&q=$lat,$lon&days=3&aqi=no&alerts=no&lang=ko');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return WeatherData.fromJson(json);
    } else {
      throw Exception('날씨 데이터를 불러오는데 실패했습니다: ${response.statusCode}');
    }
  }
}
