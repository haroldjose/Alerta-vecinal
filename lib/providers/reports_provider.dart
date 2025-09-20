import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import '../core/services/image_service.dart';
import '../core/services/location_service.dart';
import 'auth_provider.dart';

// Provider para el servicio de ubicación
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Provider para el servicio de reportes
final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

// Provider para obtener todos los reportes
final reportsStreamProvider = StreamProvider<List<ReportModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .handleError((error) {
        return const Stream.empty();
      })
      .map((snapshot) {
        return snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList();
      });
});

///

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Crear nuevo reporte
  Future<void> createReport({
    required String userId,
    required String userName,
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    LocationData? location,
  }) async {
    try {
      String? imageUrl;

      // Subir imagen si existe
      if (imageFile != null) {
        final imageService = ImageService();
        final reportId = _firestore.collection('reports').doc().id;
        imageUrl = await imageService.uploadReportImage(imageFile, reportId);
      }

      // Crear el reporte
      final report = ReportModel(
        id: '',
        userId: userId,
        userName: userName,
        problemType: problemType,
        status: ReportStatus.pendiente,
        title: title,
        description: description,
        imageUrl: imageUrl,
        location: location,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Usar batch write para asegurar consistencia
      final batch = _firestore.batch();
      final docRef = _firestore.collection('reports').doc();
      batch.set(docRef, report.toFirestore());
      await batch.commit();
    } catch (e) {
      throw 'Error al crear reporte: $e';
    }
  }

  // Actualizar estado del reporte (solo admin)
  Future<void> updateReportStatus(String reportId, ReportStatus status) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': status.value,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Error al actualizar estado: $e';
    }
  }

  // Eliminar reporte (solo admin)
  Future<void> deleteReport(String reportId) async {
    try {
      await _firestore.collection('reports').doc(reportId).delete();
    } catch (e) {
      throw 'Error al eliminar reporte: $e';
    }
  }

  // Obtener reportes por usuario
  Stream<List<ReportModel>> getReportsByUser(String userId) {
    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReportModel.fromFirestore(doc)).toList();
    });
  }
}

// StateNotifier para crear reportes 
class CreateReportNotifier extends StateNotifier<AsyncValue<void>> {
  CreateReportNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> createReport({
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    LocationData? location,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw 'Usuario no autenticado';
      }

      final reportService = ref.read(reportServiceProvider);
      await reportService.createReport(
        userId: currentUser.id,
        userName: currentUser.name,
        problemType: problemType,
        title: title,
        description: description,
        imageFile: imageFile,
        location: location,
      );

      ///
      

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

// Provider para crear reportes
final createReportProvider = StateNotifierProvider<CreateReportNotifier, AsyncValue<void>>((ref) {
  return CreateReportNotifier(ref);
});