import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  bool _isLoading = true;
  String _errorMsg = '';
  
  double _usdToPhp = 0.0;
  double _usdToKrw = 0.0;
  String _lastUpdate = '';
  
  String _baseCurrency = 'USD'; // 'USD', 'PHP', 'KRW'

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    
    try {
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'];
        
        setState(() {
          _usdToPhp = (rates['PHP'] ?? 0.0).toDouble();
          _usdToKrw = (rates['KRW'] ?? 0.0).toDouble();
          
          // 필리핀 시간 (UTC+8) 기준 현재 시각
          final nowPh = DateTime.now().toUtc().add(const Duration(hours: 8));
          
          // KST 08:59 발표는 필리핀 시간 07:59 임
          bool isAfterAnnouncement = false;
          if (nowPh.hour > 7 || (nowPh.hour == 7 && nowPh.minute >= 59)) {
            isAfterAnnouncement = true;
          }
          
          // 발표 전이면 어제 날짜 사용
          final targetDate = isAfterAnnouncement ? nowPh : nowPh.subtract(const Duration(days: 1));
          final dateStr = '${targetDate.month}/${targetDate.day}';
          
          _lastUpdate = '$dateStr 08:59(kr) 기준';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = '환율 정보를 불러오는 데 실패했습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ExchangeScreen API Error: $e');
      setState(() {
        _errorMsg = '네트워크 오류가 발생했습니다.';
        _isLoading = false;
      });
    }
  }

  double _getCalculatedValue(String targetCurrency) {
    if (_baseCurrency == targetCurrency) return 1.0;
    
    if (_baseCurrency == 'USD') {
      if (targetCurrency == 'PHP') return _usdToPhp;
      if (targetCurrency == 'KRW') return _usdToKrw;
    } else if (_baseCurrency == 'PHP') {
      if (targetCurrency == 'USD') return 1 / _usdToPhp;
      if (targetCurrency == 'KRW') return _usdToKrw / _usdToPhp;
    } else if (_baseCurrency == 'KRW') {
      if (targetCurrency == 'USD') return 1 / _usdToKrw;
      if (targetCurrency == 'PHP') return _usdToPhp / _usdToKrw;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMsg),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRates,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

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
                '오늘의 환율',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: isDarkMode ? Colors.white70 : Colors.black54),
                onPressed: _fetchRates,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _lastUpdate,
            style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white54 : Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          
          // 삼각 레이아웃 
          Row(
            children: [
              const Spacer(),
              Expanded(
                flex: 3,
                child: _buildCurrencyBox('USD', '미국 달러 (USD)', '🇺🇸', isDarkMode),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSwapIcon(isDarkMode),
              _buildSwapIcon(isDarkMode),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCurrencyBox('PHP', '필리핀 페소\n(PHP)', '🇵🇭', isDarkMode),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildSwapIcon(isDarkMode),
              ),
              Expanded(
                child: _buildCurrencyBox('KRW', '대한민국 원\n(KRW)', '🇰🇷', isDarkMode),
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: isDarkMode ? Colors.white54 : Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '본 환율 정보는 open.er-api.com 오픈 API를 통해 제공되며, 실제 거래 환율과 차이가 있을 수 있습니다. \n각 카드를 누르면 해당 통화가 1 기준으로 자동 환산됩니다.',
                    style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyBox(String currencyCode, String currencyName, String flag, bool isDarkMode) {
    final isBase = _baseCurrency == currencyCode;
    final value = _getCalculatedValue(currencyCode);
    
    String formattedValue;
    if (value == 1.0) {
      formattedValue = '1.00';
    } else if (value < 0.01) {
      formattedValue = value.toStringAsFixed(4);
    } else {
      // 컴마 추가 등은 별도 로직이 필요하나 편의상 문자열 변환 사용
      formattedValue = value.toStringAsFixed(2);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _baseCurrency = currencyCode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBase ? Colors.blue.withOpacity(0.5) : Colors.transparent,
            width: 2,
          ),
          boxShadow: isBase ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(flag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    currencyName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formattedValue,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapIcon(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.sync_alt, size: 16, color: isDarkMode ? Colors.white54 : Colors.grey[600]),
    );
  }
}
