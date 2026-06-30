import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  WeatherData? _weatherData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      // 1. 위치 권한 확인 및 요청
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('기기의 위치 서비스가 비활성화되어 있습니다.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 접근 권한이 거부되었습니다.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 접근 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.');
      }

      // 2. 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // 3. 날씨 API 호출 (위도, 경도 기반 정확한 데이터)
      final data = await _weatherService.fetchWeather(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _weatherData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.network(
              'https://assets9.lottiefiles.com/packages/lf20_jmzpqz5p.json',
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) => 
                  Icon(Icons.cloud_sync, size: 80, color: Colors.blue[300]),
            ),
            const SizedBox(height: 16),
            Text(
              '현재 위치의 날씨를 불러오는 중입니다...',
              style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다:\n$_errorMessage',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _fetchWeather();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _weatherData!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // 균형을 위한 빈 공간
              Text(
                data.locationName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: isDarkMode ? Colors.white70 : Colors.black54),
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  _fetchWeather();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '현재 날씨 정보',
            style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white54 : Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode 
                    ? [Colors.blueGrey[900]!, Colors.blueGrey[800]!] 
                    : [Colors.blue[400]!, Colors.blue[300]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: (isDarkMode ? Colors.black : Colors.blue).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      data.conditionIconUrl,
                      width: 40,
                      height: 40,
                      errorBuilder: (c, e, s) => const Icon(Icons.cloud, size: 40, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${data.tempC.toStringAsFixed(1)}°',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.conditionText,
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeatherInfoItem(Icons.thermostat, '체감온도', '${data.feelsLikeC}°C'),
                    _buildWeatherInfoItem(Icons.water_drop, '습도', '${data.humidity}%'),
                    _buildWeatherInfoItem(Icons.air, '풍속', '${data.windKph}km/h'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (data.hourlyForecast.isNotEmpty) _buildHourlyChart(data.hourlyForecast, isDarkMode),
          const SizedBox(height: 32),
          if (data.dailyForecast.isNotEmpty) _buildDailyForecast(data.dailyForecast, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildWeatherInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildHourlyChart(List<HourlyWeather> hourlyData, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '시간대별 예보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hourlyData.length,
            itemBuilder: (context, index) {
              final hour = hourlyData[index];
              return Container(
                width: 70,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hour.time,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    Image.network(
                      hour.conditionIconUrl,
                      width: 32,
                      height: 32,
                      errorBuilder: (c, e, s) => const Icon(Icons.cloud, size: 24),
                    ),
                    Text(
                      '${hour.tempC.round()}°',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (hour.chanceOfRain > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.water_drop, size: 10, color: Colors.blue[400]),
                          Text(
                            '${hour.chanceOfRain}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[400],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDailyForecast(List<DailyForecast> dailyData, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '주간 예보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dailyData.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final day = dailyData[index];
            String dayLabel = day.date;
            if (index == 0) dayLabel = '오늘';
            else if (index == 1) dayLabel = '내일';
            else if (index == 2) dayLabel = '모레';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Image.network(
                      day.conditionIconUrl,
                      width: 32,
                      height: 32,
                      errorBuilder: (c, e, s) => const Icon(Icons.cloud, size: 32),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${day.minTempC.toStringAsFixed(1)}°',
                          style: TextStyle(color: Colors.blue[300], fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.blue, Colors.red]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${day.maxTempC.toStringAsFixed(1)}°',
                          style: TextStyle(color: Colors.red[300], fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
