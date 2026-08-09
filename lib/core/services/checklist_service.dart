import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/operations/data/models/checklist_model.dart';
import 'package:flutter/foundation.dart';

class ChecklistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'checklist_submissions';

  Future<void> submitChecklist(ChecklistSubmissionModel submission) async {
    try {
      await _firestore.collection(_collection).doc(submission.id).set(submission.toMap());
    } catch (e) {
      debugPrint('Error submitting checklist: $e');
      rethrow;
    }
  }

  Stream<List<ChecklistSubmissionModel>> getSubmissionsStream({required String businessId}) {
    return _firestore
        .collection(_collection)
        .where('businessId', isEqualTo: businessId)
        .orderBy('timestampStart', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChecklistSubmissionModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
