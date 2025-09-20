import 'dart:io';
import 'package:alerta_vecinal/core/constants/colors.dart';
import 'package:alerta_vecinal/models/user_model.dart';
import 'package:alerta_vecinal/providers/auth_provider.dart';
import 'package:alerta_vecinal/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class CustomDrawer extends ConsumerStatefulWidget {
  const CustomDrawer({super.key});

  @override
  ConsumerState<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends ConsumerState<CustomDrawer> {
  
  Future<void> _changeProfileImage(UserModel user) async {
    try {
      final imageService = ref.read(imageServiceProvider);
      final File? imageFile = await imageService.showImageSourceDialogSafe(context);
      
      if (imageFile != null) {
        // Subir imagen usando el provider
        await ref.read(profileImageProvider.notifier)
            .uploadProfileImage(imageFile, user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imagen actualizada correctamente'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  ///

  Future<void> _signOut() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
    if (mounted) {
      Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final profileImageState = ref.watch(profileImageProvider);

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Header del drawer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
            ),
            child: currentUser.when(
              data: (user) {
                if (user == null) return const SizedBox();
                
                return Column(
                  children: [
                    // Círculo para foto de perfil
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _changeProfileImage(user),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.background,
                                width: 3,
                              ),
                              color: AppColors.background,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: user.profileImage != null
                                  ? Image.network(
                                      user.profileImage!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildDefaultAvatar();
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                    )
                                  : _buildDefaultAvatar(),
                            ),
                          ),
                        ),
                        
                        // Indicador de carga si se está subiendo imagen
                        if (profileImageState.isLoading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.background,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        
                        // Ícono de cámara
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: AppColors.background,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Texto de bienvenida
                    Text(
                      'Bienvenido ${user.name}',
                      style: const TextStyle(
                        color: AppColors.background,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.background),
              ),
              error: (error, stack) => const Text(
                'Error al cargar usuario',
                style: TextStyle(color: AppColors.background),
              ),
            ),
          ),
          
          // Línea separadora
          const Divider(
            color: AppColors.border,
            thickness: 1,
            height: 1,
          ),
          
          // Lista de opciones
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Cerrar sesión
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _signOut,
                ),
                
                const Divider(color: AppColors.border),
                
                ///
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.border,
      ),
      child: const Icon(
        Icons.person,
        color: AppColors.textSecondary,
        size: 50,
      ),
    );
  }
  
  ///
}





