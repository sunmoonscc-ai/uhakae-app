import 'package:study_abroad_app/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/offline_notice.dart';

class NewsScreen extends StatefulWidget {
  final String region;
  const NewsScreen({super.key, required this.region});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    if (!mounted) return;
    
    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
    });
  }

  Future<void> _refresh() async {
    await _checkConnectivity();
    // Firestore StreamBuilder will automatically update if we are back online.
    // However, if we need to manually trigger a re-fetch, we can clear cache or just rebuild.
    if (mounted && !_isOffline) {
      setState(() {});
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime date = timestamp.toDate();
    final Duration diff = DateTime.now().difference(date);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}일 전';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}시간 전';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  String _formatDateString(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime date = timestamp.toDate();
    final year = date.year.toString().substring(2);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  String get _regionCode {
    switch (widget.region) {
      case '세부': return 'cebu';
      case '보홀': return 'bohol';
      case '클락': return 'clark';
      case '바기오': return 'baguio';
      default: return 'cebu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isOffline) {
      return OfflineNotice(onRetry: _refresh);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 20),
            label: const Text('새로고침'),
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('news')
                  .where('category', isEqualTo: _regionCode) // 카테고리 필드 필터링
                  .snapshots(includeMetadataChanges: true), // 로컬 캐시 활용
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Text(
                            '뉴스를 불러오는 중 오류가 발생했습니다.',
                            style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                
                // Dart 메모리에서 발행일 순으로 정렬 (복합 인덱스 회피)
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final dateA = (dataA['published_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final dateB = (dataB['published_at'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return dateB.compareTo(dateA); // 내림차순
                });

                if (docs.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.newspaper, size: 64, color: isDarkMode ? Colors.white24 : Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                '수집된 뉴스가 없습니다.',
                                style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '서버(Cloud Functions) 연동 대기 중...',
                                style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white38 : Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['title'] ?? '제목 없음';
                    final link = data['link'] ?? '';
                    final imageUrl = data['image_url'] ?? '';
                    final source = data['source'] ?? 'Google News';
                    final publishedAt = data['published_at'] as Timestamp?;

                    return Card(
                      color: isDarkMode ? Colors.grey[900] : Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (link.isNotEmpty) {
                            _launchUrl(link);
                          } else {
                            UiUtils.showPopup(context, '링크가 올바르지 않습니다.');
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0, right: 12.0),
                                    child: Text(
                                      _formatDateString(publishedAt),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.public, size: 14, color: isDarkMode ? Colors.blue[300] : Colors.blue[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        source,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _formatTimestamp(publishedAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
