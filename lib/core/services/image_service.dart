import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // seleccionando galeria o camara
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async{
    try{
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
        );

        if(image != null){
          return File(image.path);
        }
    }catch(e){
      throw 'Error al seleccionar imagen: $e';
    }
    return null;
  }
   
   // subir imagen a Storage 
   Future<String?> uploadProfileImage(File imageFile, String userId) async{
    try{
      if (!await imageFile.exists()) {
        throw 'El archivo de imagen no existe';
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('profile_images/$userId-$timestamp.jpg');
      
      // Configurar metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'uploadedAt': timestamp.toString(),
        },
      );

      // Subir archivo con metadata
      final uploadTask = ref.putFile(imageFile, metadata);
      
      // Escuchar el progreso 
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        'Progreso: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%';
      });

      // Esperar a que termine
      final snapshot = await uploadTask;

      if(snapshot.state == TaskState.success){
        final downloadUrl = await ref.getDownloadURL();
        return downloadUrl;
      } else {
        throw 'La subida no fue exitosa. Estado: ${snapshot.state}';
      }
    } catch(e) {
      if (e.toString().contains('cancelled') || e.toString().contains('-13040')) {
        throw 'La subida fue cancelada. Verifica tu conexión a internet.';
      }
      throw 'Error al subir la imagen: $e';
    }
   }

   // eliminar imagen 
   Future<void> deleteProfileImage(String userId) async{
    try{
      // Buscar archivos que empiecen con el userId
      final listResult = await _storage.ref().child('profile_images').listAll();
      
      for (final item in listResult.items) {
        if (item.name.startsWith(userId)) {
          await item.delete();
          print('Imagen anterior eliminada: ${item.name}');
        }
      }
    }catch(e){
      'Error al eliminar imagen anterior: $e';
      
    }
   }

   // selector de imagen
   Future<File?> showImageSourceDialog(BuildContext context) async{
    final ImageSource? selectedSource = await showDialog<ImageSource?>(
      context: context, 
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Seleccionar imagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Galeria'),
                onTap: () {
                  Navigator.pop(dialogContext, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Cámara'),
                onTap: () {
                  Navigator.pop(dialogContext, ImageSource.camera);
                },
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: Text('Cancelar'))
          ],
        );
      },
    );

    // proceder a tomar la imagen
    if (selectedSource != null) {
      return await pickImage(source: selectedSource);
    }
    
    return null;
   }

   // usando showModalBottomSheet 
   Future<File?> showImageSourceBottomSheet(BuildContext context) async {
    final ImageSource? selectedSource = await showModalBottomSheet<ImageSource?>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Seleccionar de galería'),
                onTap: () {
                  Navigator.pop(bottomSheetContext, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(bottomSheetContext, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel),
                title: Text('Cancelar'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                },
              ),
            ],
          ),
        );
      },
    );

    if (selectedSource != null) {
      return await pickImage(source: selectedSource);
    }
    
    return null;
  }
}
