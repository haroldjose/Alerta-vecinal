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
    
    if (!mounted) return;
    
    final File? imageFile = await imageService.showImageSourceDialog(context);
    
    if (imageFile != null && mounted) {
      // Mostrar loading mientras se sube
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Subiendo imagen...'),
            ],
          ),
          duration: Duration(seconds: 15), // Tiempo  para la subida
        ),
      );

      // Subir la imagen con ImageService
      final String? downloadUrl = await imageService.uploadProfileImage(imageFile, user.id);
      
      if (downloadUrl != null && mounted) {
        // Actualizar el provider con la nueva URL
        await ref.read(profileImageProvider.notifier).updateProfileImageUrl(downloadUrl, user.id);
        
        // Cerrar el SnackBar de loading
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagen actualizada correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: No se pudo obtener la URL de descarga'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  } catch (e) {
    // Cerrar loading 
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

  void _navigateToProblemType(String problemType) {
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navegando a: $problemType'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // cerrar drawer
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
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 60, 16, 20),
            decoration: BoxDecoration(color: AppColors.primary),
            child: currentUser.when(
              data: (user) {
                if (user == null) return SizedBox();

                return Column(
                  children: [
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
                              child:
                                  user.profileImage != null
                                      ? Image.network(
                                        user.profileImage!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context,error,stackTrace,) {
                                          return _buildDefaultAvatar();
                                        },
                                        loadingBuilder: (
                                          context,
                                          child,
                                          loadingProgress,
                                        ) {
                                          if (loadingProgress == null) return child;
                                          return Center(
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

                        if (profileImageState.isLoading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.background,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),

                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: AppColors.background,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    Text(
                      'Bienvenido ${user.name}',
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 18,
                        fontWeight: FontWeight.w600
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
              error:
                  (error, stackTrace) => Text(
                    'Error al cargar usuario',
                    style: TextStyle(color: AppColors.background),
                  ),
              loading:
                  () => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.background,
                    ),
                  ),
            ),
          ),

          //linea de separación
          Divider(
            color: AppColors.border, 
            thickness: 1, 
            height: 1
            ),
          // opciones para las ventanas
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: AppColors.error,
                  ),
                  title: Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _signOut,
                ),

                Divider(color: AppColors.border,),

                _buildProblemTypeItem(
                  icon: Icons.security,
                  title:'Inseguridad',
                  onTap: () => _navigateToProblemType('Inseguridad'),
                ),

                _buildProblemTypeItem(
                  icon: Icons.build,
                  title:'Servicios Básicos',
                  onTap: () => _navigateToProblemType('Servicios Básicos'),
                ),

                _buildProblemTypeItem(
                  icon: Icons.eco,
                  title:'Contaminación',
                  onTap: () => _navigateToProblemType('Contaminación'),
                ),

                _buildProblemTypeItem(
                  icon: Icons.people,
                  title:'Convivencia',
                  onTap: () => _navigateToProblemType('Convivencia'),
                ),
              ],
            )
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(){
  return Container(
    width: 100,
    height: 100,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.border,
    ),
    child: Icon(
      Icons.person,
      color: AppColors.textSecondary,
      size: 50,
    ),
  );
 }

 Widget _buildProblemTypeItem({
  required IconData icon,
  required String title,
  required VoidCallback onTap,
 }){
  return ListTile(
    leading: Icon(
      icon,
      color: AppColors.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),

      onTap: onTap,
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: AppColors.textSecondary,
        size: 16,
      ),

  );
 }
 
}
