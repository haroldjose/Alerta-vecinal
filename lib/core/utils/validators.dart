class Validators {
  // Validar nombre (solo letras y espacios)
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'El nombre es requerido';
    }
    
    final nameRegex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!nameRegex.hasMatch(value)) {
      return 'El nombre solo puede contener letras';
    }
    
    if (value.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    
    return null;
  }
  
  // Validar cargo (solo letras y espacios)
  static String? validateCargo(String? value) {
    if (value == null || value.isEmpty) {
      return 'El cargo es requerido';
    }
    
    final cargoRegex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!cargoRegex.hasMatch(value)) {
      return 'El cargo solo puede contener letras';
    }
    
    if (value.trim().length < 2) {
      return 'El cargo debe tener al menos 2 caracteres';
    }
    
    return null;
  }
  
  // Validar contraseña (mínimo 6 caracteres, letras, números y símbolos)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    
    // Verificar que tenga al menos una letra
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'La contraseña debe contener al menos una letra';
    }
    
    // Verificar que tenga al menos un número o símbolo
    if (!RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'La contraseña debe contener al menos un número o símbolo';
    }
    
    return null;
  }
  
  // Validar email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Ingrese un email válido';
    }
    
    return null;
  }
}