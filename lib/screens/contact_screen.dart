import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/ui_utils.dart';

class ContactScreen extends StatefulWidget {
  final String region;

  const ContactScreen({super.key, required this.region});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(ContactScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.region != widget.region) {
      _selectedIndex = 0;
    }
  }

  List<String> get _categories {
    if (widget.region == '세부') {
      return ['대사관', '세부분관', '세부 한인회', '긴급구조', '종합병원', '전기/수도'];
    } else {
      return ['대사관'];
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (!await launchUrl(launchUri)) {
      debugPrint('Could not launch $launchUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (_categories.length > 1)
          Container(
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_categories[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      }
                    },
                    selectedColor: const Color(0xFF0066CC).withOpacity(0.1),
                    backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF0066CC)
                          : (isDarkMode ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF0066CC)
                          : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_selectedIndex == 0) ...[
                  // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0066CC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '주필리핀 대한민국 대사관',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.location_on_outlined, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Cards
          _buildContactCard(
            title: '공식 홈페이지',
            value: 'https://ph.mofa.go.kr/ph-ko/index.do',
            description: '웹사이트 방문',
            onTap: () => _launchUrl('https://ph.mofa.go.kr/ph-ko/index.do'),
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 12),
          
          _buildContactCard(
            title: '공식 페이스북',
            value: 'https://www.facebook.com/KoreanEmbassyPhilippines',
            description: '페이스북 페이지 방문',
            onTap: () => _launchUrl('https://www.facebook.com/KoreanEmbassyPhilippines'),
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 12),
          
          _buildContactCard(
            title: '대표 전화 (근무시간 내)',
            value: '+63-2-8856-9210',
            description: '평일 08:30 - 17:00',
            onTap: () => _makePhoneCall('+63288569210'),
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 12),
          
          _buildContactCard(
            title: '긴급연락처 (근무시간 외)',
            value: '+63-917-817-5703',
            description: '24시간 당직 긴급 연락망',
            onTap: () => _makePhoneCall('+639178175703'),
            isDarkMode: isDarkMode,
          ),
          ], // End of _selectedIndex == 0

          if (widget.region == '세부') ...[
            if (_selectedIndex == 1) ...[
              // Header for Cebu Consulate
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0066CC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '주필리핀 대한민국 대사관 세부분관',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.location_on_outlined, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Cards for Cebu Consulate
            _buildContactCard(
              title: '공식 홈페이지',
              value: 'https://cebu.mofa.go.kr/ph-cebu-ko/index.do',
              description: '웹사이트 방문',
              onTap: () => _launchUrl('https://cebu.mofa.go.kr/ph-cebu-ko/index.do'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '공식 페이스북',
              value: 'https://www.facebook.com/koreanconsulateincebu/',
              description: '페이스북 페이지 방문',
              onTap: () => _launchUrl('https://www.facebook.com/koreanconsulateincebu/'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '대표 전화 (근무시간 내)',
              value: '+63-32-231-1516(~1519)',
              description: '평일 08:30 - 17:00',
              onTap: () => _makePhoneCall('+63322311516'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '긴급연락처 (근무시간 외)',
              value: '+82-2-3210-0404(유료)',
              description: '24시간 영사안전콜센터',
              onTap: () => _makePhoneCall('+82232100404'),
              isDarkMode: isDarkMode,
            ),
            ], // End of _selectedIndex == 1
            
            if (_selectedIndex == 2) ...[
              // Header for Cebu Korean Association
              Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0066CC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '세부 한인회',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            _buildContactCard(
              title: '공식 페이스북',
              value: 'https://www.facebook.com/cebukorean/?locale=ko_KR',
              description: '페이스북 페이지 방문',
              onTap: () => _launchUrl('https://www.facebook.com/cebukorean/?locale=ko_KR'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '한인회 사무국',
              value: '+63-906-594-4688',
              description: '안내 및 정보 문의',
              onTap: () => _makePhoneCall('+639065944688'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '세부 한인회 상담',
              value: '카카오톡 아이디 : cebukorean',
              description: '주중 9시~6시 (주말 휴무)',
              onTap: () async {
                final Uri launchUri = Uri(
                  scheme: 'kakaotalk',
                  path: 'search',
                );
                try {
                  await launchUrl(launchUri);
                } catch (e) {
                  if (context.mounted) {
                    UiUtils.showPopup(context, '카카오톡에서 cebukorean 을 검색해주세요.');
                  }
                }
              },
              isDarkMode: isDarkMode,
            ),
            ], // End of _selectedIndex == 2
            
            if (_selectedIndex == 3) ...[
              // Header for Emergency (Cebu)
              Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0066CC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '필리핀 긴급구조 (공통)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            _buildContactCard(
              title: '경찰 / 소방 / 구급 통합신고',
              value: '911',
              description: '국번없이 911 (필리핀 전역)',
              onTap: () => _makePhoneCall('911'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '세부시티 소방서',
              value: '+63-32-414-4715',
              description: '세부 시내 화재 신고',
              onTap: () => _makePhoneCall('+63324144715'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '만다웨시티 소방서',
              value: '+63-32-344-4747 또는 +63-32-344-3364',
              description: '※ 만다웨 통합 재난 통제 센터 (CDRRMO): +63-32-383-1658 / 휴대전화: 0917-111-6633',
              onTap: () => _makePhoneCall('+63323444747'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '라푸라푸시티 소방서',
              value: '+63-32-340-0252 또는 +63-32-342-8509',
              description: '※ 최신 통합 지휘 센터 (휴대전화): 0999-972-1111 또는 0917-849-4709',
              onTap: () => _makePhoneCall('+63323400252'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '코르도바시 소방서',
              value: '+63-32-496-8663',
              description: '※ 휴대전화(비상 핫라인): 0917-149-8487 또는 0917-116-9819',
              onTap: () => _makePhoneCall('+63324968663'),
              isDarkMode: isDarkMode,
            ),
            ], // End of _selectedIndex == 3
            
            if (_selectedIndex == 4) ...[
              // Header for Hospitals
              Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0066CC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '종합병원 (응급실)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            _buildContactCard(
              title: '청화 병원 만다웨 (Chong Hua Hospital Mandaue)',
              value: '+63-32-255-8000',
              description: '만다웨 소재 대형 종합병원',
              onTap: () => _makePhoneCall('+63322558000'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '세부 닥터스 병원 (Cebu Doctors)',
              value: '+63-32-255-5555',
              description: '세부시티 중심가 종합병원',
              onTap: () => _makePhoneCall('+63322555555'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: '막탄 닥터스 병원 (Mactan Doctors)',
              value: '+63-32-239-7002(~7016)',
              description: '막탄 리조트 구역 종합병원',
              onTap: () => _makePhoneCall('+63322397002'),
              isDarkMode: isDarkMode,
            ),
            ], // End of _selectedIndex == 4
            
            if (_selectedIndex == 5) ...[
              // Header for Utilities (Electricity/Water)
              Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0066CC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '전기/수도',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            _buildContactCard(
              title: 'meco (막탄 전기)',
              value: 'https://www.facebook.com/mecomactan/',
              description: '공식 페이스북',
              onTap: () => _launchUrl('https://www.facebook.com/mecomactan/'),
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
            
            _buildContactCard(
              title: 'mcwd (막탄 수도)',
              value: 'https://www.facebook.com/metrocebuwater/',
              description: '공식 페이스북',
              onTap: () => _launchUrl('https://www.facebook.com/metrocebuwater/'),
              isDarkMode: isDarkMode,
            ),
            ], // End of _selectedIndex == 5
          ], // End of if (widget.region == '세부')
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required String title,
    required String value,
    required String description,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              description,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      final text = '$title\n$value\n$description';
                      if (kIsWeb) {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (mounted) {
                          UiUtils.showPopup(context, '연락처 정보가 클립보드에 복사되었습니다.');
                        }
                      } else {
                        try {
                          await Share.share(text);
                        } catch (e) {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (mounted) {
                            UiUtils.showPopup(context, '연락처 정보가 클립보드에 복사되었습니다.');
                          }
                        }
                      }
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.share_outlined,
                        color: Colors.blue[700],
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
