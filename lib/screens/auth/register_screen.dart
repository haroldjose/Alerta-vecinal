import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../core/utils/validators.dart';




class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Controladores de texto
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cargoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _cargoError;
  String? _roleError;
  
  bool _isLoading = false;
  UserRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    
    // Agregar listeners para validar mientras se escribe
    _nameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
    _cargoController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cargoController.dispose();
    super.dispose();
  }

  // Método se ejecuta cuando cualquier campo cambia
  void _onFieldChanged() {
    _validateAllFields();
  }

  // Validación campos mientras se escribe
  void _validateAllFields() {
    setState(() {
      // Validación campos básicos
      _nameError = _nameController.text.isNotEmpty 
          ? Validators.validateName(_nameController.text) 
          : null;
      
      _emailError = _emailController.text.isNotEmpty 
          ? Validators.validateEmail(_emailController.text) 
          : null;
      
      _passwordError = _passwordController.text.isNotEmpty 
          ? Validators.validatePassword(_passwordController.text) 
          : null;
      
      _confirmPasswordError = _confirmPasswordController.text.isNotEmpty 
          ? Validators.validateConfirmPassword(_confirmPasswordController.text, _passwordController.text) 
          : null;
      
      // Validación rol 
      _roleError = _selectedRole == null ? 'Seleccione un rol' : null;
      
      // Validación cargo  admin
      if (_selectedRole == UserRole.admin) {
        _cargoError = _cargoController.text.isNotEmpty 
            ? Validators.validateCargo(_cargoController.text) 
            : null;
      } else {
        _cargoError = null;
      }
    });
  }

  // Validación antes del envío 
  void _validateForSubmission() {
    setState(() {
      _nameError = Validators.validateName(_nameController.text);
      _emailError = Validators.validateEmail(_emailController.text);
      _passwordError = Validators.validatePassword(_passwordController.text);
      _confirmPasswordError = Validators.validateConfirmPassword(
        _confirmPasswordController.text,
        _passwordController.text,
      );
      _roleError = _selectedRole == null ? 'Seleccione un rol' : null;
      
      if (_selectedRole == UserRole.admin) {
        _cargoError = Validators.validateCargo(_cargoController.text);
      } else {
        _cargoError = null;
      }
    });
  }

  // Verificando si el formulario es válido
  bool get _isFormValid {
    final hasAllRequiredFields = _nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _selectedRole != null &&
        (_selectedRole == UserRole.user || _cargoController.text.isNotEmpty);

    final hasNoErrors = _nameError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _roleError == null &&
        (_selectedRole == UserRole.user || _cargoError == null);

    final isValid = hasAllRequiredFields && hasNoErrors;
    return isValid;
  }

  

  

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
    );
  }
}

