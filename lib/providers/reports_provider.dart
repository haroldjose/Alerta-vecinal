import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import '../models/local_models.dart';
import '../core/services/image_service.dart';
import '../core/services/location_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/local_storage_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/sync_service.dart';
import 'auth_provider.dart';

// Provider para el servicio de ubicación
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Provider para el servicio de conectividad
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

// Provider para el servicio de sincronización
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

// Provider para el estado de conectividad
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return connectivity.connectionStatus;
});

// Provider para el estado de sincronización
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final sync = ref.watch(syncServiceProvider);
  return sync.syncStatus;
});

// Provider para el servicio de reportes (híbrido: local + Firebase)
final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

// 🔄 Provider HÍBRIDO para obtener todos los reportes (local + Firebase)
final reportsStreamProvider = StreamProvider<List<ReportModel>>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  final localStorage = LocalStorageService();

  if (connectivity.hasConnection) {
    // CON INTERNET: usar Firebase
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          // Si falla Firebase, retornar datos locales
          final localReports = localStorage.getAllReports();
          final reports = localReports.map((local) => local.toReportModel()).toList();
          reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return Stream.value(reports);
        })
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ReportModel.fromFirestore(doc))
              .toList();
        });
  } else {
    // SIN INTERNET: usar datos locales como stream periódico
    return Stream.periodic(const Duration(milliseconds: 500), (_) {
      final localReports = localStorage.getAllReports();
      final reports = localReports
          .map((local) => local.toReportModel())
          .toList();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    }).distinct();
  }
});

// Provider para reportes filtrados por tipo
final reportsByTypeProvider =
    StreamProvider.family<List<ReportModel>, ProblemType>((ref, problemType) {
      final connectivity = ref.watch(connectivityServiceProvider);
      final localStorage = LocalStorageService();

      if (connectivity.hasConnection) {
        return FirebaseFirestore.instance
            .collection('reports')
            .where('problemType', isEqualTo: problemType.value)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .handleError((error) {
              final localReports = localStorage.getReportsByType(problemType);
              final reports = localReports.map((local) => local.toReportModel()).toList();
              reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Stream.value(reports);
            })
            .map((snapshot) {
              return snapshot.docs
                  .map((doc) => ReportModel.fromFirestore(doc))
                  .toList();
            });
      } else {
        return Stream.periodic(const Duration(milliseconds: 500), (_) {
          final localReports = localStorage.getReportsByType(problemType);
          final reports = localReports
              .map((local) => local.toReportModel())
              .toList();
          reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reports;
        }).distinct();
      }
    });

// Provider para los reportes del usuario actual
final myReportsStreamProvider =
    StreamProvider.family<List<ReportModel>, String>((ref, userId) {
      final connectivity = ref.watch(connectivityServiceProvider);
      final localStorage = LocalStorageService();

      if (connectivity.hasConnection) {
        return FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots()
            .handleError((error) {
              final localReports = localStorage.getReportsByUser(userId);
              final reports = localReports.map((local) => local.toReportModel()).toList();
              reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Stream.value(reports);
            })
            .map((snapshot) {
              return snapshot.docs
                  .map((doc) => ReportModel.fromFirestore(doc))
                  .toList();
            });
      } else {
        return Stream.periodic(const Duration(milliseconds: 500), (_) {
          final localReports = localStorage.getReportsByUser(userId);
          final reports = localReports
              .map((local) => local.toReportModel())
              .toList();
          reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reports;
        }).distinct();
      }
    });

// Provider para contar los reportes del usuario
final myReportsCountProvider = StreamProvider<int>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final localStorage = LocalStorageService();
  
  return currentUser.when(
    data: (user) {
      if (user == null) return Stream.value(0);
      
      if (connectivity.hasConnection) {
        return FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: user.id)
            .snapshots()
            .handleError((error) {
              final count = localStorage.getReportsByUser(user.id).length;
              return Stream.value(count);
            })
            .map((snapshot) => snapshot.docs.length);
      } else {
        return Stream.periodic(const Duration(milliseconds: 500), (_) {
          return localStorage.getReportsByUser(user.id).length;
        }).distinct();
      }
    },
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final LocalStorageService _localStorage = LocalStorageService();
  final ConnectivityService _connectivity = ConnectivityService();

  // 🔄 Crear nuevo reporte (OFFLINE-FIRST) - CORREGIDO
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
      final reportId = _firestore.collection('reports').doc().id;
      final now = DateTime.now();
      String? localImagePath;

      // Guardar imagen localmente si existe
      if (imageFile != null) {
        localImagePath = await _localStorage.saveLocalImage(imageFile, reportId);
      }

      // Crear reporte local
      final localReport = LocalReportModel(
        id: reportId,
        userId: userId,
        userName: userName,
        problemType: problemType.value,
        status: ReportStatus.pendiente.value,
        title: title,
        description: description,
        localImagePath: localImagePath,
        latitude: location?.latitude,
        longitude: location?.longitude,
        address: location?.address,
        createdAt: now,
        updatedAt: now,
        isSynced: false,
      );

      // Guardar en almacenamiento local PRIMERO
      await _localStorage.saveReport(localReport);
      print('✅ Reporte guardado localmente: $reportId');

      // Intentar sincronizar SOLO si hay conexión
      if (_connectivity.hasConnection) {
        try {
          await _syncCreateToFirebase(
            reportId: reportId,
            userId: userId,
            userName: userName,
            problemType: problemType,
            title: title,
            description: description,
            imageFile: imageFile,
            location: location,
            localImagePath: localImagePath,
            localReport: localReport,
          );
        } catch (e) {
          // Si falla la sincronización, guardar como operación pendiente
          print('⚠️ Error al sincronizar inmediatamente, se guardará para después: $e');
          await _savePendingCreateOperation(localReport, localImagePath);
        }
      } else {
        // SIN INTERNET: solo guardar operación pendiente
        print('📵 Sin conexión, reporte guardado solo localmente');
        await _savePendingCreateOperation(localReport, localImagePath);
      }
    } catch (e) {
      print('❌ Error al crear reporte: $e');
      throw 'Error al crear reporte: $e';
    }
  }

  // 🆕 MÉTODO SEPARADO para sincronizar con Firebase
  Future<void> _syncCreateToFirebase({
    required String reportId,
    required String userId,
    required String userName,
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    LocationData? location,
    String? localImagePath,
    required LocalReportModel localReport,
  }) async {
    String? imageUrl;

    // Subir imagen a Firebase Storage
    if (imageFile != null) {
      final imageService = ImageService();
      imageUrl = await imageService.uploadReportImage(imageFile, reportId);
      // Eliminar imagen local después de subirla
      await _localStorage.deleteLocalImage(reportId);
    }

    // Crear reporte en Firestore
    final report = ReportModel(
      id: reportId,
      userId: userId,
      userName: userName,
      problemType: problemType,
      status: ReportStatus.pendiente,
      title: title,
      description: description,
      imageUrl: imageUrl,
      location: location,
      createdAt: localReport.createdAt,
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('reports').doc(reportId).set(report.toFirestore());

    // Actualizar reporte local como sincronizado
    await _localStorage.saveReport(
      localReport.copyWith(isSynced: true, imageUrl: imageUrl)
    );

    // Enviar notificación
    _notificationService.sendReportNotificationToAll(
      reportId: reportId,
      reportTitle: title,
      reportType: problemType.displayName,
      creatorId: userId,
    ).catchError((error) {
      print('⚠️ Error al enviar notificación: $error');
    });

    print('✅ Reporte sincronizado con Firebase: $reportId');
  }

  Future<void> _savePendingCreateOperation(
    LocalReportModel report,
    String? localImagePath,
  ) async {
    final operation = PendingOperation(
      id: '${report.id}_create',
      type: 'create',
      reportId: report.id,
      data: {
        'userId': report.userId,
        'userName': report.userName,
        'problemType': report.problemType,
        'status': report.status,
        'title': report.title,
        'description': report.description,
        'localImagePath': localImagePath,
        'location': report.latitude != null && report.longitude != null
            ? {
                'latitude': report.latitude,
                'longitude': report.longitude,
                'address': report.address,
              }
            : null,
        'createdAt': report.createdAt.toIso8601String(),
      },
      timestamp: DateTime.now(),
    );

    await _localStorage.addPendingOperation(operation);
  }

  // 🔄 Actualizar reporte (OFFLINE-FIRST) - CORREGIDO
  Future<void> updateReport({
    required String reportId,
    required String userId,
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    String? existingImageUrl,
    LocationData? location,
  }) async {
    try {
      String? localImagePath;

      // Guardar nueva imagen localmente si existe
      if (imageFile != null) {
        localImagePath = await _localStorage.saveLocalImage(imageFile, reportId);
      }

      // Actualizar reporte local PRIMERO
      final existingReport = _localStorage.getReport(reportId);
      if (existingReport != null) {
        final updatedReport = existingReport.copyWith(
          problemType: problemType.value,
          title: title,
          description: description,
          localImagePath: localImagePath ?? existingReport.localImagePath,
          latitude: location?.latitude,
          longitude: location?.longitude,
          address: location?.address,
          updatedAt: DateTime.now(),
          isSynced: false,
        );

        await _localStorage.saveReport(updatedReport);
        print('✅ Reporte actualizado localmente: $reportId');
      }

      // Intentar sincronizar SOLO si hay conexión
      if (_connectivity.hasConnection) {
        try {
          String? imageUrl = existingImageUrl;
          if (imageFile != null) {
            final imageService = ImageService();
            imageUrl = await imageService.uploadReportImage(imageFile, reportId);
            await _localStorage.deleteLocalImage(reportId);
          }

          await _firestore.collection('reports').doc(reportId).update({
            'problemType': problemType.value,
            'title': title,
            'description': description,
            'imageUrl': imageUrl,
            'location': location?.toMap(),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

          // Marcar como sincronizado
          final report = _localStorage.getReport(reportId);
          if (report != null) {
            await _localStorage.saveReport(
              report.copyWith(isSynced: true, imageUrl: imageUrl)
            );
          }

          print('✅ Reporte actualizado en Firebase: $reportId');
        } catch (e) {
          print('⚠️ Error al sincronizar actualización: $e');
          await _savePendingUpdateOperation(
            reportId, problemType, title, description, 
            localImagePath, existingImageUrl, location
          );
        }
      } else {
        // SIN INTERNET: guardar operación pendiente
        print('📵 Sin conexión, actualización guardada localmente');
        await _savePendingUpdateOperation(
          reportId, problemType, title, description,
          localImagePath, existingImageUrl, location
        );
      }
    } catch (e) {
      print('❌ Error al actualizar reporte: $e');
      throw 'Error al actualizar reporte: $e';
    }
  }

  Future<void> _savePendingUpdateOperation(
    String reportId,
    ProblemType problemType,
    String title,
    String description,
    String? localImagePath,
    String? existingImageUrl,
    LocationData? location,
  ) async {
    final operation = PendingOperation(
      id: '${reportId}_update',
      type: 'update',
      reportId: reportId,
      data: {
        'problemType': problemType.value,
        'title': title,
        'description': description,
        'localImagePath': localImagePath,
        'existingImageUrl': existingImageUrl,
        'location': location?.toMap(),
      },
      timestamp: DateTime.now(),
    );

    await _localStorage.addPendingOperation(operation);
  }

  // Actualizar estado del reporte (solo admin)
  Future<void> updateReportStatus(String reportId, ReportStatus status) async {
    try {
      // Actualizar local
      final report = _localStorage.getReport(reportId);
      if (report != null) {
        await _localStorage.saveReport(
          report.copyWith(status: status.value, isSynced: false)
        );
      }

      if (_connectivity.hasConnection) {
        try {
          await _firestore.collection('reports').doc(reportId).update({
            'status': status.value,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });

          if (report != null) {
            await _localStorage.saveReport(
              report.copyWith(status: status.value, isSynced: true)
            );
          }
        } catch (e) {
          print('⚠️ Error al actualizar estado: $e');
          // Guardar operación pendiente
          final operation = PendingOperation(
            id: '${reportId}_status',
            type: 'updateStatus',
            reportId: reportId,
            data: {'status': status.value},
            timestamp: DateTime.now(),
          );
          await _localStorage.addPendingOperation(operation);
        }
      } else {
        // Guardar operación pendiente
        final operation = PendingOperation(
          id: '${reportId}_status',
          type: 'updateStatus',
          reportId: reportId,
          data: {'status': status.value},
          timestamp: DateTime.now(),
        );
        await _localStorage.addPendingOperation(operation);
      }
    } catch (e) {
      throw 'Error al actualizar estado: $e';
    }
  }

  // Eliminar reporte (solo admin)
  Future<void> deleteReport(String reportId) async {
    try {
      if (_connectivity.hasConnection) {
        try {
          await _firestore.collection('reports').doc(reportId).delete();
        } catch (e) {
          print('⚠️ Error al eliminar en Firebase: $e');
          // Guardar operación pendiente
          final operation = PendingOperation(
            id: '${reportId}_delete',
            type: 'delete',
            reportId: reportId,
            data: {},
            timestamp: DateTime.now(),
          );
          await _localStorage.addPendingOperation(operation);
        }
      } else {
        // Guardar operación pendiente
        final operation = PendingOperation(
          id: '${reportId}_delete',
          type: 'delete',
          reportId: reportId,
          data: {},
          timestamp: DateTime.now(),
        );
        await _localStorage.addPendingOperation(operation);
      }

      await _localStorage.deleteReport(reportId);
      await _localStorage.deleteLocalImage(reportId);
    } catch (e) {
      throw 'Error al eliminar reporte: $e';
    }
  }

  // Obtener reportes por usuario (híbrido)
  Stream<List<ReportModel>> getReportsByUser(String userId) {
    if (_connectivity.hasConnection) {
      return _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ReportModel.fromFirestore(doc))
                .toList();
          });
    } else {
      final reports = _localStorage.getReportsByUser(userId)
          .map((local) => local.toReportModel())
          .toList();
      
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(reports);
    }
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

      ref.invalidate(reportsStreamProvider);
      ref.invalidate(myReportsStreamProvider(currentUser.id));
      ref.invalidate(myReportsCountProvider);
      for (final type in ProblemType.values) {
        ref.invalidate(reportsByTypeProvider(type));
      }

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

// StateNotifier para editar reportes
class EditReportNotifier extends StateNotifier<AsyncValue<void>> {
  EditReportNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> updateReport({
    required String reportId,
    required String userId,
    required ProblemType problemType,
    required String title,
    required String description,
    File? imageFile,
    String? existingImageUrl,
    LocationData? location,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw 'Usuario no autenticado';
      }

      if (currentUser.id != userId) {
        throw 'No tienes permiso para editar este reporte';
      }

      final reportService = ref.read(reportServiceProvider);
      await reportService.updateReport(
        reportId: reportId,
        userId: userId,
        problemType: problemType,
        title: title,
        description: description,
        imageFile: imageFile,
        existingImageUrl: existingImageUrl,
        location: location,
      );

      ref.invalidate(reportsStreamProvider);
      ref.invalidate(myReportsStreamProvider(userId));
      for (final type in ProblemType.values) {
        ref.invalidate(reportsByTypeProvider(type));
      }

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
final createReportProvider =
    StateNotifierProvider<CreateReportNotifier, AsyncValue<void>>((ref) {
      return CreateReportNotifier(ref);
    });

// Provider para editar reportes
final editReportProvider =
    StateNotifierProvider<EditReportNotifier, AsyncValue<void>>((ref) {
      return EditReportNotifier(ref);
    });



