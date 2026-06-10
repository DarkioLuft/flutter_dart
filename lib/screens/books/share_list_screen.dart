import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';

class ShareListScreen extends StatefulWidget {
  const ShareListScreen({super.key});

  @override
  State<ShareListScreen> createState() => _ShareListScreenState();
}

class _ShareListScreenState extends State<ShareListScreen> {
  final Set<String> _selectedIds = {};
  bool _isGenerating = false;
  String? _generatedCode;
  List<QueryDocumentSnapshot> _docs = [];

  // Gera um código legível de 8 caracteres sem caracteres ambíguos (0/O, 1/I/L)
  static const _charset = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  String _generateShortCode() {
    final rng = Random.secure();
    return List.generate(8, (_) => _charset[rng.nextInt(_charset.length)]).join();
  }

  Future<void> _generateCode() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isGenerating = true);

    try {
      final selectedBooks = _docs
          .where((d) => _selectedIds.contains(d.id))
          .map((d) {
            final data = d.data() as Map<String, dynamic>;
            return {
              'title': data['title'] ?? '',
              'author': data['author'] ?? '',
              'pages': data['pages'] ?? 0,
              'status': data['status'] ?? 'Quero Ler',
            };
          })
          .toList();

      // Tenta até 3 vezes caso o código já exista (colisão improvável mas seguro)
      String code = '';
      for (int attempt = 0; attempt < 3; attempt++) {
        code = _generateShortCode();
        final existing = await FirebaseFirestore.instance
            .collection('shared_lists')
            .doc(code)
            .get();
        if (!existing.exists) break;
      }

      // Salva usando o código curto como ID do documento
      await FirebaseFirestore.instance
          .collection('shared_lists')
          .doc(code)
          .set({
        'books': selectedBooks,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByEmail': FirebaseAuth.instance.currentUser?.email ?? '',
        'count': selectedBooks.length,
      });

      setState(() {
        _generatedCode = code;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar código: $e'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  void _copyCode() {
    if (_generatedCode == null) return;
    Clipboard.setData(ClipboardData(text: _generatedCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Código copiado para a área de transferência!'),
          ],
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _resetCode() {
    setState(() {
      _generatedCode = null;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Compartilhar Lista'),
        backgroundColor: AppColors.surface,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('books')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_books_outlined,
                        size: 64, color: AppColors.primary.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text('Nenhum livro na estante',
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      'Adicione livros à sua estante primeiro para poder compartilhá-los.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          _docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aT = (a.data() as Map)['createdAt'] as Timestamp?;
              final bT = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aT == null && bT == null) return 0;
              if (aT == null) return 1;
              if (bT == null) return -1;
              return bT.compareTo(aT);
            });

          if (_generatedCode != null) {
            return _CodeResultView(
              code: _generatedCode!,
              bookCount: _selectedIds.length,
              onCopy: _copyCode,
              onReset: _resetCode,
            );
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Selecione os livros que deseja compartilhar. Um código curto será gerado para outro usuário importar.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('${_selectedIds.length} de ${_docs.length} selecionados',
                        style: AppTextStyles.labelBold),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == _docs.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(_docs.map((d) => d.id));
                          }
                        });
                      },
                      icon: Icon(
                        _selectedIds.length == _docs.length
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _selectedIds.length == _docs.length
                            ? 'Desmarcar todos'
                            : 'Selecionar todos',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                      top: 8, bottom: 100, left: 16, right: 16),
                  itemCount: _docs.length,
                  itemBuilder: (context, index) {
                    final doc = _docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedIds.contains(doc.id);
                    return _SelectableBookCard(
                      data: data,
                      isSelected: isSelected,
                      onToggle: () {
                        setState(() {
                          isSelected
                              ? _selectedIds.remove(doc.id)
                              : _selectedIds.add(doc.id);
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _generatedCode == null
          ? AnimatedScale(
              scale: _selectedIds.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton.extended(
                onPressed: _isGenerating ? null : _generateCode,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code_rounded),
                label: Text(_isGenerating
                    ? 'Gerando...'
                    : 'Gerar Código (${_selectedIds.length})'),
              ),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────
// Card selecionável de livro
// ─────────────────────────────────────────────

class _SelectableBookCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSelected;
  final VoidCallback onToggle;

  const _SelectableBookCard({
    required this.data,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.cardShadow,
              blurRadius: isSelected ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title'] ?? '',
                      style: AppTextStyles.labelBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(data['author'] ?? '',
                      style: AppTextStyles.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusChip(status: data['status'] ?? ''),
                      const SizedBox(width: 8),
                      Text('${data['pages'] ?? 0} págs.',
                          style: AppTextStyles.bodyMedium.copyWith(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tela de resultado com o código gerado
// ─────────────────────────────────────────────

class _CodeResultView extends StatelessWidget {
  final String code;
  final int bookCount;
  final VoidCallback onCopy;
  final VoidCallback onReset;

  const _CodeResultView({
    required this.code,
    required this.bookCount,
    required this.onCopy,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.success, size: 56),
          ),
          const SizedBox(height: 20),
          Text('Código Gerado!', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '$bookCount ${bookCount == 1 ? 'livro incluído' : 'livros incluídos'} — sem anotações',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 32),

          // Box do código — agora exibe o código COMPLETO (ele É o código curto)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.tag_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text('Código de compartilhamento',
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                // Código dividido em dois blocos de 4 para facilitar leitura
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CodeBlock(text: code.substring(0, 4)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('—',
                          style: TextStyle(
                              fontSize: 24,
                              color: AppColors.primary.withOpacity(0.4),
                              fontWeight: FontWeight.w300)),
                    ),
                    _CodeBlock(text: code.substring(4, 8)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Compartilhe este código com quem desejar. Ele pode ser digitado diretamente na importação.',
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Anotações não são incluídas. Apenas título, autor, páginas e status são compartilhados.',
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('COPIAR CÓDIGO'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Gerar outro código'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;
  const _CodeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          letterSpacing: 8,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}