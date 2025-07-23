import 'package:alerta_vecinal/core/constants/strings.dart';

class Validators {

  static bool isValidName(String name){
    return RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(name);
  }

  static bool isValidPassword(String password){
    return password.length >= 6;
  }

  static bool isValidPosition(String position){
    return RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(position);
  }

  static String? validateName(String? value){
    if(value == null || value.isEmpty){
      return 'Este campo es requerido';
    }
    if(!isValidName(value)){
      return AppString.nameError;
    }
    return null;
  }

  static String? validatePassword(String? value){
    if(value == null || value.isEmpty){
      return 'Este campo es requerido';
    }
    if(!isValidPassword(value)){
      return AppString.passwordError;
    }
    return null;
  }
  
  static String? validatePosition(String? value){
    if(value == null || value.isEmpty){
      return 'Este campo es requerido';
    }
    if(!isValidPosition(value)){
      return AppString.positionError;
    }
    return null;
  }



}