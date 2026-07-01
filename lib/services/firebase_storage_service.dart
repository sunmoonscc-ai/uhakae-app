import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class FirebaseStorageService {
  /// 이미지를 Firebase Storage에 업로드하고 다운로드 URL을 반환합니다.
  static Future<String?> uploadImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final String uuid = const Uuid().v4();
      final String extension = file.name.contains('.') ? file.name.split('.').last : 'png';
      final String fileName = '$uuid.$extension';
      
      // uploads 폴더 밑에 고유한 파일 이름으로 저장
      final Reference ref = FirebaseStorage.instance.ref().child('uploads/$fileName');
      
      // MIME 타입 설정 (선택 사항이지만 웹에서는 권장)
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/$extension',
      );
      
      // 바이트 데이터 업로드
      final UploadTask uploadTask = ref.putData(bytes, metadata);
      
      // 업로드 완료 대기
      final TaskSnapshot snapshot = await uploadTask;
      
      // 업로드된 파일의 다운로드 URL 가져오기
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
      
    } catch (e) {
      print('Firebase Storage upload error: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultipleImages(List<XFile> files, String pathPrefix) async {
    List<String> urls = [];
    for (var file in files) {
      try {
        final bytes = await file.readAsBytes();
        final String uuid = const Uuid().v4();
        final String extension = file.name.contains('.') ? file.name.split('.').last : 'png';
        final String fileName = '$uuid.$extension';
        
        final Reference ref = FirebaseStorage.instance.ref().child('$pathPrefix/$fileName');
        final SettableMetadata metadata = SettableMetadata(
          contentType: 'image/$extension',
        );
        
        final UploadTask uploadTask = ref.putData(bytes, metadata);
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        urls.add(downloadUrl);
      } catch (e) {
        print('Firebase Storage uploadMultipleImages error: $e');
      }
    }
    return urls;
  }
}
