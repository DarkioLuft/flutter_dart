import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('books')
          .where('userId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final books = snapshot.data?.docs ?? [];

        // Cálculo das estatísticas
        int totalBooks = books.length;
        int booksRead = 0;
        int booksReading = 0;
        int booksWantToRead = 0;
        int totalPagesRead = 0;

        for (var doc in books) {
          final data = doc.data() as Map<String, dynamic>;
          switch (data['status']) {
            case 'Lido':
              booksRead++;
              totalPagesRead += (data['pages'] as num? ?? 0).toInt();
            case 'Lendo':
              booksReading++;
            default:
              booksWantToRead++;
          }
        }

        // Porcentagem de leitura concluída
        final double readPercent = totalBooks > 0 ? (booksRead / totalBooks) : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Olá, ${user?.email?.split('@').first ?? 'leitor'} 👋', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 4),
              Text('Veja o resumo das suas leituras', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 24),

              // Barra de progresso geral
              _ProgressCard(percent: readPercent, booksRead: booksRead, total: totalBooks),
              const SizedBox(height: 20),

              // Grid de stats
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Total de Livros',
                      value: totalBooks.toString(),
                      icon: Icons.library_books_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Lidos',
                      value: booksRead.toString(),
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.statusRead,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Lendo',
                      value: booksReading.toString(),
                      icon: Icons.auto_stories_rounded,
                      color: AppColors.statusReading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Quero Ler',
                      value: booksWantToRead.toString(),
                      icon: Icons.bookmark_border_rounded,
                      color: AppColors.statusWantToRead,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatCard(
                title: 'Páginas Lidas no Total',
                value: totalPagesRead.toString(),
                icon: Icons.menu_book_rounded,
                color: AppColors.secondary,
                fullWidth: true,
              ),

              const SizedBox(height: 28),

              // Seção de motivação
              if (totalBooks == 0) _EmptyDashboardHint(),
              if (totalBooks > 0 && booksRead > 0) _MotivationCard(booksRead: booksRead),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Card de progresso visual
// ─────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final double percent;
  final int booksRead;
  final int total;

  const _ProgressCard({required this.percent, required this.booksRead, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progresso Geral', style: AppTextStyles.labelBold),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.labelBold.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            total == 0 ? 'Adicione livros para começar!' : '$booksRead de $total livros concluídos',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Card de motivação
// ─────────────────────────────────────────────

class _MotivationCard extends StatelessWidget {
  final int booksRead;
  const _MotivationCard({required this.booksRead});

  String get _message {
    if (booksRead >= 20) return '🏆 Incrível! Você é um leitor voraz!';
    if (booksRead >= 10) return '🌟 Você já leu $booksRead livros! Continue assim!';
    if (booksRead >= 5) return '🚀 Já são $booksRead livros! Você está pegando o ritmo!';
    return '📖 Ótimo começo! Cada livro é uma nova aventura.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(_message, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────
// Dica quando o dashboard está vazio
// ─────────────────────────────────────────────

class _EmptyDashboardHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.tips_and_updates_outlined, color: AppColors.primary, size: 32),
          const SizedBox(height: 10),
          Text(
            'Vá para "Minha Estante" e adicione seu primeiro livro para ver as estatísticas aqui!',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}