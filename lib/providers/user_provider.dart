
import 'dart:io';

import 'package:alerta_vecinal/core/services/image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final imageServiceProvider = Provider<ImageService>((ref){
  return ImageService();
});

final userServiceProvider = Provider<UserService>((ref){
  return UserService();
});

class UserService{
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// actualizar imagen 
  Future<void> updateProfileImage(String userId, String imageUrl) async{
    print('💾 Actualizando imagen en Firestore para usuario: $userId');
    print('🔗 URL de la imagen: $imageUrl');
    
    try{
      await _firestore.collection('users').doc(userId).update({'profileImage': imageUrl});
      print('✅ Imagen actualizada en Firestore exitosamente');
    }catch(e){
      print('❌ Error al actualizar imagen en Firestore: $e');
      throw 'Error al actualizar imagen de perfil: $e';
    }
  }

  // actualizar usuario
  Future<void> updateUser(String userId, Map<String,dynamic> data) async{
    print('💾 Actualizando datos de usuario: $userId');
    print('📊 Datos: $data');
    
    try{
      await _firestore.collection('users').doc(userId).update(data);
      print('✅ Usuario actualizado exitosamente');
    }catch(e){
      print('❌ Error al actualizar usuario: $e');
      throw 'Error al actualizar usuario: $e';
    }
  }
}

//manejar subida imagen perfil
class ProfileImageNotifier extends StateNotifier<AsyncValue<String?>>{
  final Ref ref;
  ProfileImageNotifier(this.ref) : super(AsyncValue.data(null));

 //subir la imagen
 Future<void> uploadProfileImage(File imageFile, String userId) async{
  print('🚀 Iniciando subida de imagen al provider');
  print('📂 Archivo: ${imageFile.path}');
  print('👤 Usuario ID: $userId');
  
  state = AsyncValue.loading();
  
  try{
    final imageService = ref.read(imageServiceProvider);
    final userService = ref.read(userServiceProvider);

    print('☁️ Subiendo imagen a Firebase Storage...');
    final imageUrl = await imageService.uploadProfileImage(imageFile, userId);

    if(imageUrl != null){
      print('✅ Imagen subida exitosamente. URL: $imageUrl');
      print('💾 Actualizando base de datos...');
      
      await userService.updateProfileImage(userId, imageUrl);
      
      print('🎉 Proceso completado exitosamente');
      state = AsyncValue.data(imageUrl);
    }else{
      print('❌ La subida de imagen retornó null');
      state = AsyncValue.error('No se pudo subir la imagen', StackTrace.empty);
    }
  }catch(e, stack){
    print('❌ Error en uploadProfileImage: $e');
    print('📍 Stack trace: $stack');
    state = AsyncValue.error(e.toString(), stack);
  }
 }

 void reset(){
  print('🔄 Reseteando estado del ProfileImageNotifier');
  state = AsyncValue.data(null);
 }

 // Método alternativo para actualizar directamente (método de respaldo)
 Future<void> updateProfileImageUrl(String downloadUrl, String userId) async {
    print('🔄 Método alternativo: actualizando URL directamente');
    print('🔗 URL: $downloadUrl');
    print('👤 Usuario: $userId');
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId) 
          .update({'profileImage': downloadUrl});
      
      print('✅ URL actualizada directamente en Firestore');
      state = AsyncValue.data(downloadUrl);
    } catch (e) {
      print('❌ Error en updateProfileImageUrl: $e');
      throw 'Error al actualizar la base de datos: $e';
    }
  }
}

final profileImageProvider = StateNotifierProvider<ProfileImageNotifier, AsyncValue<String?>>((ref){
 return ProfileImageNotifier(ref);
});


