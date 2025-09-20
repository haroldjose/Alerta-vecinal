import 'package:alerta_vecinal/core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_drawer.dart';

import '../../providers/reports_provider.dart';

import '../../widgets/report_card.dart';
import '../../widgets/custom_button.dart';
import '../reports/create_report_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final reportsAsync = ref.watch(reportsStreamProvider);

    // Escucha cambios en el provider de creación de reportes
    ref.listen<AsyncValue<void>>(createReportProvider, (previous, next) {
      next.whenData((_) {
        
        if (previous?.isLoading == true) {
          ref.invalidate(reportsStreamProvider);
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alerta Vecinal'),
        backgroundColor: AppColors.primary,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
      ),
      drawer: const CustomDrawer(),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No hay usuario autenticado'));
          }

          return reportsAsync.when(
            data: (reports) {
              if (reports.isEmpty) {
                // Mostrar mensaje y bóton
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.report_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No se tienen reportes',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),
                        CustomButton(
                          text: 'Crear Reporte',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const CreateReportScreen(),
                              ),
                            );
                          },
                          width: 200,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Mostrar lista de reportes
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(reportsStreamProvider);
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ReportCard(report: reports[index]),
                    );
                  },
                ),
              );
            },
            loading:
                () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
            error:
                (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar reportes',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(reportsStreamProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        error:
            (error, stack) => Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateReportScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}





