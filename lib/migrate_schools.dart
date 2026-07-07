import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final List<String> schoolList = [
    '바기오_BECI', '바기오_CIJ', '바기오_PINES',
    '보홀_Mint',
    '세부_B\'Cebu', '세부_BK Academy', '세부_Blue Ocean', '세부_E FRIENDS',
    '세부_JJES', '세부_JOYFUL EDUCATION', '세부_JUNGLE', '세부_PIZZA',
    '세부_QQ', '세부_SEL Academy', '세부_SMEAG capital', '세부_SMEAG encanto', '세부_Winning English',
    '클락_E&G',
  ];
  for (var s in schoolList) {
    final doc = await FirebaseFirestore.instance.collection('schools').doc(s).get();
    if (!doc.exists) {
      await FirebaseFirestore.instance.collection('schools').doc(s).set({'features': '', 'location': ''});
    }
  }
}
