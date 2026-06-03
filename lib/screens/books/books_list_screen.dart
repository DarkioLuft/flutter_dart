import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/empty_state.dart';
import 'book_form_screen.dart';
import '../notes/notes_list_screen.dart';

class BooksListScreen extends StatelessWidget {
  const BooksListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          // Sem orderBy: evita a necessidade de índice composto no Firestore.
          // A ordenação é feita em memória logo abaixo.
          stream: FirebaseFirestore.instance
              .collection('books')
              .where('userId', isEqualTo: user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Mostra erro caso a query falhe (ex: índice faltando)
            if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const EmptyState(
                icon: Icons.library_books_outlined,
                title: 'Sua estante está vazia',
                subtitle: 'Toque no + para adicionar seu primeiro livro!',
              );
            }

            // Ordenação em memória: mais recentes primeiro
            final docs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

            return ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 90),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final bookData = doc.data() as Map<String, dynamic>;
                return _BookCard(doc: doc, bookData: bookData);
              },
            );
          },
        ),

        // FAB posicionado sobre o conteúdo
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookFormScreen()),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo Livro'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Card individual de livro
// ─────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> bookData;

  const _BookCard({required this.doc, required this.bookData});

  Future<void> _deleteBook(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir livro?'),
        content: const Text('As anotações deste livro também serão excluídas. Deseja continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Deleta subcoleção de notas antes de deletar o livro
    final notesSnapshot = await FirebaseFirestore.instance
        .collection('books')
        .doc(doc.id)
        .collection('notes')
        .get();

    for (final noteDoc in notesSnapshot.docs) {
      await noteDoc.reference.delete();
    }

    await FirebaseFirestore.instance.collection('books').doc(doc.id).delete();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Livro e anotações excluídos.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppDecorations.card,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotesListScreen(
              bookId: doc.id,
              bookTitle: bookData['title'] ?? '',
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone de livro
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),

              // Informações do livro
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookData['title'] ?? '',
                      style: AppTextStyles.labelBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bookData['author'] ?? '',
                      style: AppTextStyles.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusChip(status: bookData['status'] ?? ''),
                        const SizedBox(width: 8),
                        Text(
                          '${bookData['pages'] ?? 0} págs.',
                          style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Botões de ação
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppColors.primary,
                    tooltip: 'Editar',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookFormScreen(
                          bookId: doc.id,
                          initialData: bookData,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AppColors.accent,
                    tooltip: 'Excluir',
                    onPressed: () => _deleteBook(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}