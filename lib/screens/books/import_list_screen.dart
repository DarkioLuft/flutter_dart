import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';

class ImportListScreen extends StatefulWidget {
  const ImportListScreen({super.key});

  @override
  State<ImportListScreen> createState() => _ImportListScreenState();
}

class _ImportListScreenState extends State<ImportListScreen> {
  final _codeEC = TextEditingController();
  bool _isDecoding = false;
  bool _isImporting = false;

  // Lista de livros decodificados do código
  List<Map<String, dynamic>> _previewBooks = [];

  // Quais livros o usuário quer importar (índice)
  Set<int> _selectedIndices = {};

  // Metadados do compartilhamento
  String? _sharedBy;
  int? _sharedCount;

  String? _errorMessage;

  @override
  void dispose() {
    _codeEC.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _codeEC.text = data!.text!.trim();
    }
  }

  Future<void> _decodeCode() async {
    final raw = _codeEC.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'Cole ou digite o código de importação.');
      return;
    }

    setState(() {
      _isDecoding = true;
      _errorMessage = null;
      _previewBooks = [];
      _selectedIndices = {};
    });

    try {
      // O código tem formato: PREFIXO.BASE64
      final parts = raw.split('.');
      if (parts.length < 2) {
        throw const FormatException('Formato de código inválido.');
      }

      // Tudo após o primeiro ponto é o base64 (base64 pode conter '=')
      final base64Part = parts.sublist(1).join('.');

      final bytes = base64Url.decode(base64Part);
      final jsonStr = utf8.decode(bytes);
      final payload = jsonDecode(jsonStr) as Map<String, dynamic>;

      final books = (payload['books'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (books.isEmpty) {
        throw const FormatException('O código não contém livros.');
      }

      setState(() {
        _previewBooks = books;
        _selectedIndices = Set.from(List.generate(books.length, (i) => i));
        _sharedBy = payload['createdBy'] as String?;
        _sharedCount = payload['count'] as int?;
        _isDecoding = false;
      });
    } catch (e) {
      setState(() {
        _isDecoding = false;
        _errorMessage =
            'Código inválido ou corrompido. Verifique e tente novamente.';
      });
    }
  }

  Future<void> _importSelected() async {
    if (_selectedIndices.isEmpty) return;

    setState(() => _isImporting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance.collection('books');

      for (final i in _selectedIndices) {
        final book = _previewBooks[i];
        final ref = col.doc(); // novo documento
        batch.set(ref, {
          'userId': user!.uid,
          'title': book['title'] ?? '',
          'author': book['author'] ?? '',
          'pages': book['pages'] ?? 0,
          'status': book['status'] ?? 'Quero Ler',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'importedFrom': true,
        });
      }

      await batch.commit();

      if (!mounted) return;

      final count = _selectedIndices.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                  '$count ${count == 1 ? 'livro importado' : 'livros importados'} com sucesso!'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _isImporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao importar: $e'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      _codeEC.clear();
      _previewBooks = [];
      _selectedIndices = {};
      _sharedBy = null;
      _sharedCount = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Importar Lista'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Seção do código ──
            Text('Código de Importação', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Cole o código recebido de outro usuário para visualizar e importar os livros.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 20),

            // Campo de código
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeEC,
                    decoration: AppDecorations.inputDecoration(
                      'Cole o código aqui...',
                      icon: Icons.qr_code_rounded,
                    ).copyWith(
                      suffixIcon: _codeEC.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  color: AppColors.textSecondary),
                              onPressed: _reset,
                            )
                          : null,
                      errorText: _errorMessage,
                    ),
                    onChanged: (_) => setState(() => _errorMessage = null),
                    maxLines: 3,
                    minLines: 1,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Botões colar e decodificar
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('Colar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isDecoding || _previewBooks.isNotEmpty
                            ? null
                            : _decodeCode,
                    icon: _isDecoding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                    label: Text(
                        _isDecoding ? 'Verificando...' : 'Verificar Código'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            // ── Preview dos livros ──
            if (_previewBooks.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),

              // Cabeçalho do preview
              Row(
                children: [
                  const Icon(Icons.preview_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Livros no Código',
                      style: AppTextStyles.headlineSmall),
                ],
              ),
              const SizedBox(height: 6),

              // Metadados do compartilhamento
              if (_sharedBy != null)
                Text(
                  'Compartilhado por: $_sharedBy  •  ${_sharedCount ?? _previewBooks.length} livros',
                  style:
                      AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                ),
              const SizedBox(height: 14),

              // Barra selecionar todos
              Row(
                children: [
                  Text(
                    '${_selectedIndices.length} de ${_previewBooks.length} selecionados',
                    style: AppTextStyles.labelBold,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_selectedIndices.length ==
                            _previewBooks.length) {
                          _selectedIndices.clear();
                        } else {
                          _selectedIndices = Set.from(List.generate(
                              _previewBooks.length, (i) => i));
                        }
                      });
                    },
                    icon: Icon(
                      _selectedIndices.length == _previewBooks.length
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _selectedIndices.length == _previewBooks.length
                          ? 'Desmarcar todos'
                          : 'Selecionar todos',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Lista de preview
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _previewBooks.length,
                itemBuilder: (context, index) {
                  final book = _previewBooks[index];
                  final isSelected =
                      _selectedIndices.contains(index);

                  return _PreviewBookCard(
                    book: book,
                    isSelected: isSelected,
                    onToggle: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIndices.remove(index);
                        } else {
                          _selectedIndices.add(index);
                        }
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              // Aviso: sem anotações
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.warning.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Apenas título, autor, páginas e status serão importados. Sem anotações.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botão importar
              SizedBox(
                width: double.infinity,
                child: _isImporting
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _selectedIndices.isEmpty
                            ? null
                            : _importSelected,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          'IMPORTAR ${_selectedIndices.length} ${_selectedIndices.length == 1 ? 'LIVRO' : 'LIVROS'}',
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Usar outro código'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Card de preview de livro para importação
// ─────────────────────────────────────────────

class _PreviewBookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final bool isSelected;
  final VoidCallback onToggle;

  const _PreviewBookCard({
    required this.book,
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
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),

            // Ícone
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 12),

            // Dados do livro
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title'] ?? '',
                    style: AppTextStyles.labelBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    book['author'] ?? '',
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusChip(status: book['status'] ?? ''),
                      const SizedBox(width: 8),
                      Text(
                        '${book['pages'] ?? 0} págs.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontSize: 11),
                      ),
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