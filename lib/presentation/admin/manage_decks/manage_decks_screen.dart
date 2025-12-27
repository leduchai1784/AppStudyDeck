import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../routes/app_routes.dart';

class ManageDecksScreen extends StatefulWidget {
  const ManageDecksScreen({super.key});

  @override
  State<ManageDecksScreen> createState() => _ManageDecksScreenState();
}

class _ManageDecksScreenState extends State<ManageDecksScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  List<Map<String, dynamic>> _decks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final decks = await _firestoreRepo.getAllDecksForAdmin();
      setState(() {
        _decks = decks;
        _isLoading = false;
      });
      debugPrint('✅ Loaded ${decks.length} decks');
    } catch (e) {
      debugPrint('❌ Error loading decks: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải danh sách deck: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredDecks {
    var filtered = List<Map<String, dynamic>>.from(_decks);
    
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered.where((deck) {
        final name = (deck['name'] as String? ?? '').toLowerCase();
        final description = (deck['description'] as String? ?? '').toLowerCase();
        final authorName = (deck['authorName'] as String? ?? '').toLowerCase();
        return name.contains(lowerQuery) || 
               description.contains(lowerQuery) ||
               authorName.contains(lowerQuery);
      }).toList();
    }
    
    return filtered;
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Deck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Tìm kiếm'),
                  content: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Nhập từ khóa tìm kiếm...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      Navigator.of(context).pop();
                      _performSearch(value);
            },
          ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        Navigator.of(context).pop();
                        _performSearch('');
                      },
                      child: const Text('Xóa'),
                    ),
                    FilledButton(
            onPressed: () {
                        Navigator.of(context).pop();
                        _performSearch(_searchController.text);
                      },
                      child: const Text('Tìm'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips - removed since we only show public decks now
          // Can add user filter later if needed
          // Deck list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDecks.isEmpty
                    ? _EmptyDeckList()
                    : RefreshIndicator(
                        onRefresh: _loadDecks,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredDecks.length,
                          itemBuilder: (context, index) {
                            final deck = _filteredDecks[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.collections_bookmark,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                title: Text(deck['name'] ?? 'Unknown'),
                                subtitle: Text('${deck['flashcardCount'] ?? 0} flashcard • ${deck['authorName'] ?? 'Unknown'}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.deckReview,
                                    arguments: deck['deckId'] ?? deck['id'],
                                  ).then((_) => _loadDecks());
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDeckList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có deck công khai',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Các deck công khai của user sẽ hiển thị ở đây',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
