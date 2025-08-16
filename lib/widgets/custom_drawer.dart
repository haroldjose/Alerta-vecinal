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
      final File? imageFile = await imageService.showImageSourceDialog(context);
      if (imageFile != null) {
        await ref
            .read(profileImageProvider.notifier)
            .uploadProfileImage(imageFile, user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
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
    
  }


 
}
