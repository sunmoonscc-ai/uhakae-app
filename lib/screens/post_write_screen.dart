import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostWriteScreen extends StatefulWidget {
  const PostWriteScreen({super.key});

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'community';
  bool _isSaving = false;
  
  final List<String> _adminEmails = [
    'cebufriends79@gmail.com',
    'slptas05@gmail.com',
    'sunmoon.scc@gmail.com',
    'hdcc6th@gmail.com',
  ];

  Future<void> _savePost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('posts').doc();
      final bool isAdmin = _adminEmails.contains(user.email);
      
      final postData = {
        'post_id': docRef.id,
        'category': _selectedCategory,
        'author_id': user.uid,
        'author_name': isAdmin ? '관리자' : (user.email?.split('@')[0] ?? '일반사용자'),
        'title': title,
        'content': content,
        'created_at': FieldValue.serverTimestamp(),
        'is_synced': true,
      };

      // 오프라인 상태일 경우 캐시에 즉시 저장되고 나중에 동기화됩니다.
      await docRef.set(postData);

      if (mounted) {
        // 스낵바로 오프라인 지속성 안내
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('게시글이 저장되었습니다. (네트워크 오프라인 시 연결 후 자동 업로드됩니다.)'),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user != null && _adminEmails.contains(user.email);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('글쓰기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePost,
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('등록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (isAdmin) ...[
              Row(
                children: [
                  const Text('게시판 선택:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: Colors.grey[900],
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'community', child: Text('자유 게시판')),
                      DropdownMenuItem(value: 'notice', child: Text('공지사항')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
            ],
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              decoration: const InputDecoration(
                hintText: '제목을 입력하세요',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white38),
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: TextField(
                controller: _contentController,
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: '내용을 작성해주세요.\n\n오프라인 상태에서도 작성 및 저장이 가능하며, 네트워크 복구 시 자동으로 서버에 동기화됩니다.',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
