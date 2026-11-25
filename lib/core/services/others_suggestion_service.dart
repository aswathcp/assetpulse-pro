import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OthersSuggestion {
  final String id;
  final String collection;
  final String suggestedName;
  final String? context;
  final String? submittedByUserId;
  final String? submittedByName;
  final String? plantId;
  final String? unitId;
  final DateTime submittedAt;
  final String status;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final String? reviewedByName;

  const OthersSuggestion({
    required this.id,
    required this.collection,
    required this.suggestedName,
    this.context,
    this.submittedByUserId,
    this.submittedByName,
    this.plantId,
    this.unitId,
    required this.submittedAt,
    this.status = 'pending',
    this.reviewNote,
    this.reviewedAt,
    this.reviewedByName,
  });

  factory OthersSuggestion.fromMap(Map<String, dynamic> m, String id) {
    return OthersSuggestion(
      id: id,
      collection: m['collection'] ?? '',
      suggestedName: m['suggestedName'] ?? '',
      context: m['context'],
      submittedByUserId: m['submittedByUserId'],
      submittedByName: m['submittedByName'],
      plantId: m['plantId'],
      unitId: m['unitId'],
      submittedAt: (m['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: m['status'] ?? 'pending',
      reviewNote: m['reviewNote'],
      reviewedAt: (m['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedByName: m['reviewedByName'],
    );
  }

  Map<String, dynamic> toMap() => {
        'collection': collection,
        'suggestedName': suggestedName,
        'context': context,
        'submittedByUserId': submittedByUserId,
        'submittedByName': submittedByName,
        'plantId': plantId,
        'unitId': unitId,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': status,
        'reviewNote': reviewNote,
        'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
        'reviewedByName': reviewedByName,
      };
}

class OthersSuggestionService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'others_suggestions';

  static Future<String> submit({
    required String collection,
    required String suggestedName,
    String? context,
    String? submittedByUserId,
    String? submittedByName,
    String? plantId,
    String? unitId,
  }) async {
    final existing = await _db
        .collection(_col)
        .where('collection', isEqualTo: collection)
        .where('suggestedName', isEqualTo: suggestedName.trim())
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;
    final ref = await _db.collection(_col).add({
      'collection': collection,
      'suggestedName': suggestedName.trim(),
      'context': context,
      'submittedByUserId': submittedByUserId,
      'submittedByName': submittedByName,
      'plantId': plantId,
      'unitId': unitId,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    return ref.id;
  }

  static Stream<List<OthersSuggestion>> pendingStream() {
    return _db
        .collection(_col)
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => OthersSuggestion.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  static Stream<List<OthersSuggestion>> allStream({String? filterCollection}) {
    Query q = _db.collection(_col).orderBy('submittedAt', descending: true);
    if (filterCollection != null) q = q.where('collection', isEqualTo: filterCollection);
    return q.snapshots().map((s) => s.docs.map((d) => OthersSuggestion.fromMap(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  static Future<void> approve(String id, {String? reviewedByName, String? note}) async {
    await _db.collection(_col).doc(id).update({
      'status': 'approved',
      'reviewNote': note,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedByName': reviewedByName,
    });
    debugPrint('OthersSuggestionService: Approved suggestion $id');
  }

  static Future<void> reject(String id, {String? reviewedByName, String? note}) async {
    await _db.collection(_col).doc(id).update({
      'status': 'rejected',
      'reviewNote': note,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedByName': reviewedByName,
    });
  }

  static Future<void> delete(String id) async {
    await _db.collection(_col).doc(id).delete();
  }

  static Future<int> pendingCount() async {
    final snap = await _db.collection(_col).where('status', isEqualTo: 'pending').count().get();
    return snap.count ?? 0;
  }
}
