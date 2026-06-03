import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

class BookFormScreen extends StatefulWidget {
  final String? bookId;
  final Map<String, dynamic>? initialData;

  const BookFormScreen({super.key, this.bookId, this.initialData});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleEC;
  late final TextEditingController _authorEC;
  late final TextEditingController _pagesEC;
  String _status = 'Quero Ler';
  bool _isLoading = false;

  final List<String> _statusOptions = ['Quero Ler', 'Lendo', 'Lido'];

  bool get _isEditing => widget.bookId != null;

  @override
  void initState() {
    super.initState();
    _titleEC = TextEditingController(text: widget.initialData?['title'] ?? '');
    _authorEC = TextEditingController(text: widget.initialData?['author'] ?? '');
    _pagesEC = TextEditingController(
        text: widget.initialData?['pages']?.toString() ?? '');
    if (widget.initialData != null) {
      _status = widget.initialData!['status'] ?? 'Quero Ler';
    }
  }

  @override
  void dispose() {
    _titleEC.dispose();
    _authorEC.dispose();
    _pagesEC.dispose();
    super.dispose();
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    final bookData = {
      'userId': user!.uid,
      'title': _titleEC.text.trim(),
      'author': _authorEC.text.trim(),
      'pages': int.tryParse(_pagesEC.text.trim()) ?? 0,
      'status': _status,
      'updatedAt': FieldValue.serverTimestamp(),
      // createdAt só é inserido na criação
      if (!_isEditing) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (!_isEditing) {
        await FirebaseFirestore.instance.collection('books').add(bookData);
      } else {
        await FirebaseFirestore.instance
            .collection('books')
            .doc(widget.bookId)
            .update(bookData);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Livro atualizado!' : 'Livro adicionado à estante!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: AppColors.accent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Livro' : 'Novo Livro'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header da seção
              Text('Informações do Livro', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 6),
              Text('Preencha os dados abaixo para salvar.', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 24),

              // Campo: Título
              TextFormField(
                controller: _titleEC,
                textCapitalization: TextCapitalization.words,
                decoration: AppDecorations.inputDecoration(
                  'Título do Livro *',
                  icon: Icons.title_rounded,
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Informe o título' : null,
              ),
              const SizedBox(height: 16),

              // Campo: Autor
              TextFormField(
                controller: _authorEC,
                textCapitalization: TextCapitalization.words,
                decoration: AppDecorations.inputDecoration(
                  'Autor *',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Informe o autor' : null,
              ),
              const SizedBox(height: 16),

              // Campo: Páginas
              TextFormField(
                controller: _pagesEC,
                keyboardType: TextInputType.number,
                decoration: AppDecorations.inputDecoration(
                  'Total de Páginas *',
                  icon: Icons.numbers_rounded,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Informe o número de páginas';
                  final n = int.tryParse(val.trim());
                  if (n == null || n <= 0) return 'Insira um número válido (maior que 0)';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo: Status (dropdown estilizado)
              Text('Status de Leitura', style: AppTextStyles.labelBold),
              const SizedBox(height: 10),
              _StatusSelector(
                selected: _status,
                options: _statusOptions,
                onChanged: (val) => setState(() => _status = val),
              ),
              const SizedBox(height: 32),

              // Botão salvar
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _saveBook,
                        icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                        label: Text(_isEditing ? 'SALVAR ALTERAÇÕES' : 'ADICIONAR LIVRO'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Seletor de status visual (substituindo Dropdown)
// ─────────────────────────────────────────────

class _StatusSelector extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _StatusSelector({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  Color _colorFor(String status) => switch (status) {
        'Lido' => AppColors.statusRead,
        'Lendo' => AppColors.statusReading,
        _ => AppColors.statusWantToRead,
      };

  IconData _iconFor(String status) => switch (status) {
        'Lido' => Icons.check_circle_outline_rounded,
        'Lendo' => Icons.auto_stories_rounded,
        _ => Icons.bookmark_border_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((option) {
        final isSelected = option == selected;
        final color = _colorFor(option);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.12) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFFE5E7EB),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(_iconFor(option), color: isSelected ? color : AppColors.textSecondary, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      option,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? color : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}