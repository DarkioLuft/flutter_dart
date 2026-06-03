import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class NotesListScreen extends StatelessWidget {
  final String bookId;
  final String bookTitle;

  const NotesListScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Anotações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(
              bookTitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('books')
                .doc(bookId)
                .collection('notes')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyState(
                  icon: Icons.sticky_note_2_outlined,
                  title: 'Nenhuma anotação ainda',
                  subtitle: 'Toque no + para registrar pensamentos, citações ou marcações de página.',
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.only(top: 12, bottom: 90),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final noteData = doc.data() as Map<String, dynamic>;
                  return _NoteCard(
                    doc: doc,
                    noteData: noteData,
                    bookId: bookId,
                  );
                },
              );
            },
          ),

          // FAB para nova anotação
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () => _showNoteDialog(context),
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Anotar'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Diálogo compartilhado para criar e editar ──

  void _showNoteDialog(
    BuildContext context, {
    String? noteId,
    Map<String, dynamic>? initialData,
  }) {
    final refEC = TextEditingController(text: initialData?['reference'] ?? '');
    final textEC = TextEditingController(text: initialData?['text'] ?? '');
    final formKey = GlobalKey<FormState>();
    final bool isEditing = noteId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle visual
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEditing ? 'Editar Anotação' : 'Nova Anotação',
                  style: AppTextStyles.headlineSmall,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: refEC,
                  decoration: AppDecorations.inputDecoration(
                    'Página ou Capítulo *',
                    icon: Icons.bookmark_outline_rounded,
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Informe a referência' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: textEC,
                  decoration: AppDecorations.inputDecoration(
                    'Sua anotação *',
                    icon: Icons.notes_rounded,
                  ),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Escreva sua anotação' : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          final noteData = {
                            'reference': refEC.text.trim(),
                            'text': textEC.text.trim(),
                            if (!isEditing) 'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          };

                          final collection = FirebaseFirestore.instance
                              .collection('books')
                              .doc(bookId)
                              .collection('notes');

                          if (isEditing) {
                            await collection.doc(noteId).update(noteData);
                          } else {
                            await collection.add(noteData);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(isEditing ? 'Salvar' : 'Adicionar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Card individual de anotação
// ─────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> noteData;
  final String bookId;

  const _NoteCard({
    required this.doc,
    required this.noteData,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    // Referência ao pai para abrir o diálogo de edição
    final notesScreen = context.findAncestorWidgetOfExactType<NotesListScreen>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppDecorations.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: referência + ações
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bookmark_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        noteData['reference'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Botão editar
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.textSecondary,
                  tooltip: 'Editar',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                  onPressed: () => notesScreen?._showNoteDialog(
                    context,
                    noteId: doc.id,
                    initialData: noteData,
                  ),
                ),
                const SizedBox(width: 4),
                // Botão deletar
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.accent,
                  tooltip: 'Excluir',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Excluir anotação?'),
                        content: const Text('Esta ação não pode ser desfeita.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) await doc.reference.delete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Texto da anotação
            Text(noteData['text'] ?? '', style: AppTextStyles.bodyLarge),
          ],
        ),
      ),
    );
  }
}