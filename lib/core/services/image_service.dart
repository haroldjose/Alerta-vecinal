import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // seleccionando imagen galeria o camara

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
   

   // subir imagen a Firebase Storage

   Future<String?> uploadProfileImage(File imageFile, String userId) async{
    try{
      final ref = _storage.ref().child('profile_image/$userId.jpg');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;

      if(snapshot.state == TaskState.success){
        final donwloadUrl = await ref.getDownloadURL();
        return donwloadUrl;
      }
    }catch(e){
      throw 'Error al subir la imagen: $e';
    }
    return null;
   }
   // eliminar imagen
   Future<void> deleteProfileImage(String userId)async{
    try{
      final ref = _storage.ref().child('profile_image/$userId.jpg');
      await ref.delete();
    }catch(e){
      throw 'error al eliminar imagen: $e';
    }
   }

   // selector de imagen

   Future<File?> showImageSourceDialog(context) async{
    return await showDialog<File?>(
      context: context, 
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleccionar imagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Galeria'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await pickImage(source:  ImageSource.gallery);
                  Navigator.pop(context, file);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Cámara'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await pickImage(source:  ImageSource.camera);
                  Navigator.pop(context, file);
                },
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('Cancelar'))
          ],
        );
      },
      );
   }







}