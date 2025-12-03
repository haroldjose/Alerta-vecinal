import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../models/user_model.dart';

// Modelo para usuarios activos
class ActiveUser {
  final String id;
  final String name;
  final String email;
  final DateTime lastActive;
  final bool isOnline;

  ActiveUser({
    required this.id,
    required this.name,
    required this.email,
    required this.lastActive,
    required this.isOnline,
  });

  factory ActiveUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastActive = (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    return ActiveUser(
      id: doc.id,
      name: data['name'] ?? 'Usuario',
      email: data['email'] ?? '',
      lastActive: lastActive,
      isOnline: difference.inMinutes < 5, // Considerado online si estuvo activo hace menos de 5 minutos
    );
  }

  String get statusText {
    if (isOnline) return 'En línea';
    
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    
    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    }
  }
}

// Provider para obtener usuarios activos (stream)
final activeUsersProvider = StreamProvider<List<ActiveUser>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('lastActive', descending: true)
      .limit(50) // Limitar a los últimos 50 usuarios
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => ActiveUser.fromFirestore(doc)).toList();
  });
});

// Provider para actualizar la última actividad del usuario
final userActivityServiceProvider = Provider((ref) => UserActivityService());

class UserActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Actualizar última actividad del usuario
  Future<void> updateUserActivity(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user activity: $e');
    }
  }

  // Inicializar listener para actualizar actividad periódicamente
  void startActivityTracking(String userId) {
    // Actualizar inmediatamente
    updateUserActivity(userId);
    
    // Programar actualizaciones periódicas cada 2 minutos
    Future.delayed(const Duration(minutes: 2), () {
      updateUserActivity(userId);
      startActivityTracking(userId); // Recursivo
    });
  }
}