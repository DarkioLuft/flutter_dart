import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// IMPORTANTE: Este arquivo será gerado automaticamente quando você rodar o 'flutterfire configure'
import 'firebase_options.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa o Firebase com as opções geradas para a sua plataforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BookLogApp());
}

class BookLogApp extends StatelessWidget {
  const BookLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

// ============================================================================
// 1. AUTENTICAÇÃO E ROTEAMENTO INICIAL
// ============================================================================

/// O AuthWrapper ouve as mudanças de estado da autenticação.
/// Se o usuário estiver logado, mostra a HomeScreen. Senão, mostra a LoginScreen.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailEC = TextEditingController();
  final _passwordEC = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailEC.text.trim(),
          password: _passwordEC.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailEC.text.trim(),
          password: _passwordEC.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Erro na autenticação'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.menu_book, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'BookLog',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailEC,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                  validator: (val) => val != null && val.contains('@') ? null : 'Insira um e-mail válido',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordEC,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                  validator: (val) => val != null && val.length >= 6 ? null : 'A senha deve ter pelo menos 6 caracteres',
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submitAuth,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text(_isLogin ? 'ENTRAR' : 'CADASTRAR', style: const TextStyle(fontSize: 16)),
                      ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'Criar uma nova conta' : 'Já tenho uma conta'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. MENU CENTRALIZADO (HomeScreen)
// ============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const DashboardScreen(), // Recurso Extra
    const BooksListScreen(), // Listagem / Relatório
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BookLog'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Sair',
          )
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Minha Estante'),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. RECURSO EXTRA: Dashboard de Estatísticas
// ============================================================================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      // Busca apenas os livros do usuário logado
      stream: FirebaseFirestore.instance.collection('books').where('userId', isEqualTo: user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final books = snapshot.data?.docs ?? [];
        int totalBooks = books.length;
        int booksRead = 0;
        int totalPagesRead = 0;

        for (var doc in books) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'Lido') {
            booksRead++;
            totalPagesRead += (data['pages'] as num).toInt();
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumo da sua leitura', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _StatCard(title: 'Total de Livros', value: totalBooks.toString(), icon: Icons.book)),
                  const SizedBox(width: 16),
                  Expanded(child: _StatCard(title: 'Livros Lidos', value: booksRead.toString(), icon: Icons.check_circle, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 16),
              _StatCard(title: 'Páginas Lidas (Total)', value: totalPagesRead.toString(), icon: Icons.pages, color: Colors.blue),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCard({required this.title, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color ?? Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. CRUD 1: LISTAGEM E FORMULÁRIO DE LIVROS
// ============================================================================

class BooksListScreen extends StatelessWidget {
  const BooksListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('books').where('userId', isEqualTo: user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum livro cadastrado. Adicione um!'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final bookData = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.book)),
                  title: Text(bookData['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${bookData['author']} • ${bookData['status']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteBook(doc.id, context),
                  ),
                  onTap: () {
                    // Ao clicar no livro, abre a tela de notas (CRUD 2)
                    Navigator.push(context, MaterialPageRoute(builder: (_) => NotesListScreen(bookId: doc.id, bookTitle: bookData['title'])));
                  },
                  onLongPress: () {
                    // Editar livro
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BookFormScreen(bookId: doc.id, initialData: bookData)));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookFormScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteBook(String docId, BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir livro?'),
        content: const Text('Isso também excluirá as anotações relacionadas (na lógica completa). Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('books').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Livro excluído.')));
    }
  }
}

class BookFormScreen extends StatefulWidget {
  final String? bookId;
  final Map<String, dynamic>? initialData;

  const BookFormScreen({super.key, this.bookId, this.initialData});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleEC;
  late TextEditingController _authorEC;
  late TextEditingController _pagesEC;
  String _status = 'Quero Ler';
  bool _isLoading = false;

  final List<String> _statusOptions = ['Quero Ler', 'Lendo', 'Lido'];

  @override
  void initState() {
    super.initState();
    _titleEC = TextEditingController(text: widget.initialData?['title'] ?? '');
    _authorEC = TextEditingController(text: widget.initialData?['author'] ?? '');
    _pagesEC = TextEditingController(text: widget.initialData?['pages']?.toString() ?? '');
    if (widget.initialData != null) {
      _status = widget.initialData!['status'];
    }
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
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.bookId == null) {
        await FirebaseFirestore.instance.collection('books').add(bookData); // CREATE
      } else {
        await FirebaseFirestore.instance.collection('books').doc(widget.bookId).update(bookData); // UPDATE
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Livro salvo com sucesso!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.bookId == null ? 'Novo Livro' : 'Editar Livro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleEC,
                decoration: const InputDecoration(labelText: 'Título do Livro', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorEC,
                decoration: const InputDecoration(labelText: 'Autor', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pagesEC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total de Páginas', border: OutlineInputBorder()),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Campo obrigatório';
                  if (int.tryParse(val) == null || int.parse(val) <= 0) return 'Insira um número válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _status = val!),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveBook,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                      child: const Text('SALVAR', style: TextStyle(fontSize: 16)),
                    )
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. CRUD 2: LISTAGEM E FORMULÁRIO DE ANOTAÇÕES
// ============================================================================

class NotesListScreen extends StatelessWidget {
  final String bookId;
  final String bookTitle;

  const NotesListScreen({super.key, required this.bookId, required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Anotações: $bookTitle')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('books').doc(bookId).collection('notes').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhuma anotação para este livro.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final noteData = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Pág / Cap: ${noteData['reference']}'),
                  subtitle: Text(noteData['text']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => doc.reference.delete(), // DELETE ANOTAÇÃO
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteDialog(context),
        child: const Icon(Icons.add_comment),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context) {
    final refEC = TextEditingController();
    final textEC = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Anotação'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: refEC,
                decoration: const InputDecoration(labelText: 'Página ou Capítulo'),
                validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: textEC,
                decoration: const InputDecoration(labelText: 'Sua anotação'),
                maxLines: 3,
                validator: (val) => val == null || val.isEmpty ? 'Obrigatório' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await FirebaseFirestore.instance.collection('books').doc(bookId).collection('notes').add({
                  'reference': refEC.text.trim(),
                  'text': textEC.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                }); // CREATE ANOTAÇÃO
                Navigator.pop(ctx);
              }
            },
            child: const Text('Salvar'),
          )
        ],
      ),
    );
  }
}