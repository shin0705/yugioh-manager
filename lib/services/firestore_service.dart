// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 현재 로그인 유저 uid
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// 현재 유저의 cards 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _cards =>
      _db.collection('users').doc(_uid).collection('cards');

  Future<void> addCard(Map<String, dynamic> data) async {
    await _cards.add(data);
  }

  Stream<QuerySnapshot> getCards() {
    return _cards.snapshots();
  }

  Future<void> deleteCard(String docId) async {
    await _cards.doc(docId).delete();
  }

  Future<void> updateCard(String docId, Map<String, dynamic> data) async {
    await _cards.doc(docId).update(data);
  }

  Future<void> changeCardCount(String docId, int delta) async {
    final ref = _cards.doc(docId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final current = (data['count'] ?? 0) as int;
      final next = (current + delta).clamp(0, 99);
      tx.update(ref, {'count': next});
    });
  }
}

