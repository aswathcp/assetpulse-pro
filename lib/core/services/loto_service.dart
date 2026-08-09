import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/operations/data/models/loto_model.dart';

class LotoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'loto_requests';

  // Create a new LOTO request
  Future<void> createRequest(LotoModel loto) async {
    await _firestore.collection(_collection).doc(loto.id).set(loto.toMap());
  }

  // Approve/Activate LOTO (Isolator Action)
  Future<void> approveRequest(String lotoId, String approverId, String approverName) async {
    await _firestore.collection(_collection).doc(lotoId).update({
      'status': LotoStatus.active.name,
      'approverId': approverId,
      'approverName': approverName,
      'activeAt': DateTime.now().toIso8601String(),
    });
  }

  // Reject Request
  Future<void> rejectRequest(String lotoId, String approverId, String approverName) async {
    await _firestore.collection(_collection).doc(lotoId).update({
      'status': LotoStatus.rejected.name,
      'approverId': approverId,
      'approverName': approverName,
      'completedAt': DateTime.now().toIso8601String(), // Treated as closed
    });
  }

  // Complete/De-isolate (Isolator Action)
  Future<void> completeRequest(String lotoId) async {
    await _firestore.collection(_collection).doc(lotoId).update({
      'status': LotoStatus.completed.name,
      'completedAt': DateTime.now().toIso8601String(),
    });
  }

  // Stream: Active Isolation Requests (Pending or Active)
  // For Lists
  Stream<List<LotoModel>> getActiveLotos() {
    return _firestore
        .collection(_collection)
        .where('status', whereIn: [LotoStatus.requested.name, LotoStatus.active.name])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LotoModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Stream: My Requests
  Stream<List<LotoModel>> getMyRequests(String userId) {
    return _firestore
        .collection(_collection)
        .where('requesterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LotoModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
