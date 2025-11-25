import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import '../core/services/image_service.dart';
import '../core/services/location_service.dart';
import '../core/services/notification_service.dart';
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
        return snapshot.docs
            .map((doc) => ReportModel.fromFirestore(doc))
            .toList();
      });
});

// Provider para reportes filtrados por tipo
final reportsByTypeProvider =
    StreamProvider.family<List<ReportModel>, ProblemType>((ref, problemType) {
      return FirebaseFirestore.instance
          .collection('reports')
          .where('problemType', isEqualTo: problemType.value)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
            return const Stream.empty();
          })
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ReportModel.fromFirestore(doc))
                .toList();
          });
    });

// Provider para los reportes del usuario actual (Mis Reportes)
final myReportsStreamProvider =
    StreamProvider.family<List<ReportModel>, String>((ref, userId) {
      return FirebaseFirestore.instance
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
            return const Stream.empty();
          })
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ReportModel.fromFirestore(doc))
                .toList();
          });
    });

// Provider para contar los reportes del usuario
final myReportsCountProvider = StreamProvider<int>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  
  return currentUser.when(
    data: (user) {
      if (user == null) return Stream.value(0);
      
      return FirebaseFirestore.instance
          .collection('reports')
          .where('userId', isEqualTo: user.id)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    },
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

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

      // 🔔 ENVIAR NOTIFICACIÓN A TODOS LOS USUARIOS
      // Se ejecuta de forma asíncrona para no bloquear la creación del reporte
      _notificationService.sendReportNotificationToAll(
        reportId: docRef.id,
        reportTitle: title,
        reportType: problemType.displayName,
        creatorId: userId,
      ).catchError((error) {
        print('⚠️ Error al enviar notificación: $error');
        // No propagamos el error para no afectar la creación del reporte
      });

    } catch (e) {
      throw 'Error al crear reporte: $e';
    }
  }

  // Actualizar reporte (solo el creador puede editar)
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
      String? imageUrl = existingImageUrl;

      // Si hay nueva imagen, subirla
      if (imageFile != null) {
        final imageService = ImageService();
        imageUrl = await imageService.uploadReportImage(imageFile, reportId);
      }

      // Actualizar el reporte
      await _firestore.collection('reports').doc(reportId).update({
        'problemType': problemType.value,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'location': location?.toMap(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw 'Error al actualizar reporte: $e';
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
          return snapshot.docs
              .map((doc) => ReportModel.fromFirestore(doc))
              .toList();
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

      ref.invalidate(reportsStreamProvider);
      ref.invalidate(myReportsStreamProvider(currentUser.id));
      ref.invalidate(myReportsCountProvider);
      for (final problemType in ProblemType.values) {
        ref.invalidate(reportsByTypeProvider(problemType));
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

      // Verificar que el usuario sea el creador
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
      for (final problemType in ProblemType.values) {
        ref.invalidate(reportsByTypeProvider(problemType));
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












// import 'dart:io';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/report_model.dart';
// import '../core/services/image_service.dart';
// import '../core/services/location_service.dart';
// import 'auth_provider.dart';

// // Provider para el servicio de ubicación
// final locationServiceProvider = Provider<LocationService>((ref) {
//   return LocationService();
// });

// // Provider para el servicio de reportes
// final reportServiceProvider = Provider<ReportService>((ref) {
//   return ReportService();
// });

// // Provider para obtener todos los reportes
// final reportsStreamProvider = StreamProvider<List<ReportModel>>((ref) {
//   return FirebaseFirestore.instance
//       .collection('reports')
//       .orderBy('createdAt', descending: true)
//       .snapshots()
//       .handleError((error) {
//         return const Stream.empty();
//       })
//       .map((snapshot) {
//         return snapshot.docs
//             .map((doc) => ReportModel.fromFirestore(doc))
//             .toList();
//       });
// });

// // Provider para reportes filtrados por tipo
// final reportsByTypeProvider =
//     StreamProvider.family<List<ReportModel>, ProblemType>((ref, problemType) {
//       return FirebaseFirestore.instance
//           .collection('reports')
//           .where('problemType', isEqualTo: problemType.value)
//           .orderBy('createdAt', descending: true)
//           .snapshots()
//           .handleError((error) {
//             return const Stream.empty();
//           })
//           .map((snapshot) {
//             return snapshot.docs
//                 .map((doc) => ReportModel.fromFirestore(doc))
//                 .toList();
//           });
//     });

// // Provider para los reportes del usuario actual (Mis Reportes)
// final myReportsStreamProvider =
//     StreamProvider.family<List<ReportModel>, String>((ref, userId) {
//       return FirebaseFirestore.instance
//           .collection('reports')
//           .where('userId', isEqualTo: userId)
//           .orderBy('createdAt', descending: true)
//           .snapshots()
//           .handleError((error) {
//             return const Stream.empty();
//           })
//           .map((snapshot) {
//             return snapshot.docs
//                 .map((doc) => ReportModel.fromFirestore(doc))
//                 .toList();
//           });
//     });

// // Provider para contar los reportes del usuario
// final myReportsCountProvider = StreamProvider<int>((ref) {
//   final currentUser = ref.watch(currentUserProvider);
  
//   return currentUser.when(
//     data: (user) {
//       if (user == null) return Stream.value(0);
      
//       return FirebaseFirestore.instance
//           .collection('reports')
//           .where('userId', isEqualTo: user.id)
//           .snapshots()
//           .map((snapshot) => snapshot.docs.length);
//     },
//     loading: () => Stream.value(0),
//     error: (_, __) => Stream.value(0),
//   );
// });

// class ReportService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Crear nuevo reporte
//   Future<void> createReport({
//     required String userId,
//     required String userName,
//     required ProblemType problemType,
//     required String title,
//     required String description,
//     File? imageFile,
//     LocationData? location,
//   }) async {
//     try {
//       String? imageUrl;

//       // Subir imagen si existe
//       if (imageFile != null) {
//         final imageService = ImageService();
//         final reportId = _firestore.collection('reports').doc().id;
//         imageUrl = await imageService.uploadReportImage(imageFile, reportId);
//       }

//       // Crear el reporte
//       final report = ReportModel(
//         id: '',
//         userId: userId,
//         userName: userName,
//         problemType: problemType,
//         status: ReportStatus.pendiente,
//         title: title,
//         description: description,
//         imageUrl: imageUrl,
//         location: location,
//         createdAt: DateTime.now(),
//         updatedAt: DateTime.now(),
//       );

//       // Usar batch write para asegurar consistencia
//       final batch = _firestore.batch();
//       final docRef = _firestore.collection('reports').doc();
//       batch.set(docRef, report.toFirestore());
//       await batch.commit();
//     } catch (e) {
//       throw 'Error al crear reporte: $e';
//     }
//   }

//   // Actualizar reporte (solo el creador puede editar)
//   Future<void> updateReport({
//     required String reportId,
//     required String userId,
//     required ProblemType problemType,
//     required String title,
//     required String description,
//     File? imageFile,
//     String? existingImageUrl,
//     LocationData? location,
//   }) async {
//     try {
//       String? imageUrl = existingImageUrl;

//       // Si hay nueva imagen, subirla
//       if (imageFile != null) {
//         final imageService = ImageService();
//         imageUrl = await imageService.uploadReportImage(imageFile, reportId);
//       }

//       // Actualizar el reporte
//       await _firestore.collection('reports').doc(reportId).update({
//         'problemType': problemType.value,
//         'title': title,
//         'description': description,
//         'imageUrl': imageUrl,
//         'location': location?.toMap(),
//         'updatedAt': Timestamp.fromDate(DateTime.now()),
//       });
//     } catch (e) {
//       throw 'Error al actualizar reporte: $e';
//     }
//   }

//   // Actualizar estado del reporte (solo admin)
//   Future<void> updateReportStatus(String reportId, ReportStatus status) async {
//     try {
//       await _firestore.collection('reports').doc(reportId).update({
//         'status': status.value,
//         'updatedAt': Timestamp.fromDate(DateTime.now()),
//       });
//     } catch (e) {
//       throw 'Error al actualizar estado: $e';
//     }
//   }

//   // Eliminar reporte (solo admin)
//   Future<void> deleteReport(String reportId) async {
//     try {
//       await _firestore.collection('reports').doc(reportId).delete();
//     } catch (e) {
//       throw 'Error al eliminar reporte: $e';
//     }
//   }

//   // Obtener reportes por usuario
//   Stream<List<ReportModel>> getReportsByUser(String userId) {
//     return _firestore
//         .collection('reports')
//         .where('userId', isEqualTo: userId)
//         .orderBy('createdAt', descending: true)
//         .snapshots()
//         .map((snapshot) {
//           return snapshot.docs
//               .map((doc) => ReportModel.fromFirestore(doc))
//               .toList();
//         });
//   }
// }

// // StateNotifier para crear reportes
// class CreateReportNotifier extends StateNotifier<AsyncValue<void>> {
//   CreateReportNotifier(this.ref) : super(const AsyncValue.data(null));

//   final Ref ref;

//   Future<void> createReport({
//     required ProblemType problemType,
//     required String title,
//     required String description,
//     File? imageFile,
//     LocationData? location,
//   }) async {
//     state = const AsyncValue.loading();

//     try {
//       final currentUser = await ref.read(currentUserProvider.future);
//       if (currentUser == null) {
//         throw 'Usuario no autenticado';
//       }

//       final reportService = ref.read(reportServiceProvider);
//       await reportService.createReport(
//         userId: currentUser.id,
//         userName: currentUser.name,
//         problemType: problemType,
//         title: title,
//         description: description,
//         imageFile: imageFile,
//         location: location,
//       );

//       ref.invalidate(reportsStreamProvider);
//       ref.invalidate(myReportsStreamProvider(currentUser.id));
//       ref.invalidate(myReportsCountProvider);
//       for (final problemType in ProblemType.values) {
//         ref.invalidate(reportsByTypeProvider(problemType));
//       }

//       state = const AsyncValue.data(null);
//     } catch (e, stack) {
//       state = AsyncValue.error(e.toString(), stack);
//     }
//   }

//   void reset() {
//     state = const AsyncValue.data(null);
//   }
// }

// // StateNotifier para editar reportes
// class EditReportNotifier extends StateNotifier<AsyncValue<void>> {
//   EditReportNotifier(this.ref) : super(const AsyncValue.data(null));

//   final Ref ref;

//   Future<void> updateReport({
//     required String reportId,
//     required String userId,
//     required ProblemType problemType,
//     required String title,
//     required String description,
//     File? imageFile,
//     String? existingImageUrl,
//     LocationData? location,
//   }) async {
//     state = const AsyncValue.loading();

//     try {
//       final currentUser = await ref.read(currentUserProvider.future);
//       if (currentUser == null) {
//         throw 'Usuario no autenticado';
//       }

//       // Verificar que el usuario sea el creador
//       if (currentUser.id != userId) {
//         throw 'No tienes permiso para editar este reporte';
//       }

//       final reportService = ref.read(reportServiceProvider);
//       await reportService.updateReport(
//         reportId: reportId,
//         userId: userId,
//         problemType: problemType,
//         title: title,
//         description: description,
//         imageFile: imageFile,
//         existingImageUrl: existingImageUrl,
//         location: location,
//       );

//       ref.invalidate(reportsStreamProvider);
//       ref.invalidate(myReportsStreamProvider(userId));
//       for (final problemType in ProblemType.values) {
//         ref.invalidate(reportsByTypeProvider(problemType));
//       }

//       state = const AsyncValue.data(null);
//     } catch (e, stack) {
//       state = AsyncValue.error(e.toString(), stack);
//     }
//   }

//   void reset() {
//     state = const AsyncValue.data(null);
//   }
// }

// // Provider para crear reportes
// final createReportProvider =
//     StateNotifierProvider<CreateReportNotifier, AsyncValue<void>>((ref) {
//       return CreateReportNotifier(ref);
//     });

// // Provider para editar reportes
// final editReportProvider =
//     StateNotifierProvider<EditReportNotifier, AsyncValue<void>>((ref) {
//       return EditReportNotifier(ref);
//     });



