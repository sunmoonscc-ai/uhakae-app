import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_storage_service.dart';
import '../utils/ui_utils.dart';

class SubmitInfoScreen extends StatefulWidget {
  final String? initialType; // e.g., '환율', '주유', '디렉토리'
  final String? businessPath;

  const SubmitInfoScreen({super.key, this.initialType, this.businessPath});

  @override
  State<SubmitInfoScreen> createState() => _SubmitInfoScreenState();
}

class _SubmitInfoScreenState extends State<SubmitInfoScreen> {
  final _contentCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _submit() async {
    if (_contentCtrl.text.trim().isEmpty) {
      UiUtils.showPopup(context, '내용을 입력해주세요.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      UiUtils.showPopup(context, '로그인이 필요합니다.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await FirebaseStorageService.uploadImage(_selectedImage!);
      }
      
      String reporterName = user.email ?? 'Unknown';
      if (user.email != null) {
        final querySnapshot = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user.email).limit(1).get();
        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          final name = data['name'] ?? '';
          final school = data['school'] ?? '';
          if (name.isNotEmpty && school.isNotEmpty) {
            reporterName = '$school > $name';
          } else if (name.isNotEmpty) {
            reporterName = name;
          }
        }
      }

      await FirebaseFirestore.instance.collection('info_suggestions').add({
        'userId': user.uid,
        'userEmail': user.email ?? 'Unknown',
        'reporterName': reporterName,
        'type': widget.initialType ?? '디렉토리',
        'businessPath': widget.businessPath ?? '',
        'content': _contentCtrl.text.trim(),
        'imageUrl': imageUrl ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        UiUtils.showPopup(context, '제보가 성공적으로 접수되었습니다. 관리자 검토 후 반영됩니다.');
      }
    } catch (e) {
      if (mounted) {
        UiUtils.showPopup(context, '오류 발생: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('새로운 정보 제보'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '변경된 정보나 사진을 제보해 주세요!\n관리자 검토 후 앱에 반영됩니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '변경된 상세 내용 (가격 등)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  setState(() => _selectedImage = image);
                }
              },
              icon: const Icon(Icons.photo),
              label: const Text('사진 첨부 (선택)'),
            ),
            if (_selectedImage != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text('사진 첨부 완료: ${_selectedImage!.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('제보하기', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
