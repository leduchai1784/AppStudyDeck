import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../../data/models/deck_model.dart';
import '../../../data/models/flashcard_model.dart';
import '../../routes/app_routes.dart';
import '../../../core/services/auth_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  List<DeckModel> _deckResults = [];
  List<FlashcardModel> _flashcardResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _deckResults = [];
        _flashcardResults = [];
        _hasSearched = false;
      });
      return;
    }

    // Debounce search
    final currentQuery = query;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim() == currentQuery && currentQuery.isNotEmpty) {
        _performSearch(currentQuery);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _deckResults = [];
        _flashcardResults = [];
        _hasSearched = false;
      });
      return;
    }

      setState(() {
        _isSearching = true;
        _hasSearched = true;
      });

    try {
      // Search decks
      debugPrint('🔍 Searching decks with query: "$query"');
      final decksData = await _firestoreRepo.searchDecks(query);
      debugPrint('✅ Found ${decksData.length} decks from search');
      
      final decksList = <DeckModel>[];
      final currentUserId = AuthService.currentUserId;
      
      for (var data in decksData) {
        try {
          debugPrint('📦 Processing deck data: ${data['deckId']}');
          final deck = _convertToDeckModel(data);
          bool isFavorite = false;
          
          if (currentUserId != null) {
            try {
              isFavorite = await _firestoreRepo.isDeckFavorited(currentUserId, deck.id);
            } catch (e) {
              debugPrint('⚠️ Error checking favorite: $e');
            }
          }
          
          decksList.add(DeckModel(
            id: deck.id,
            name: deck.name,
            description: deck.description,
            authorId: deck.authorId,
            authorName: deck.authorName,
            flashcardCount: deck.flashcardCount,
            viewCount: deck.viewCount,
            favoriteCount: deck.favoriteCount,
            isPublic: deck.isPublic,
            isFavorite: isFavorite,
            createdAt: deck.createdAt,
            updatedAt: deck.updatedAt,
          ));
          debugPrint('✅ Added deck: ${deck.name}');
        } catch (e, stackTrace) {
          debugPrint('❌ Error processing deck: $e');
          debugPrint('❌ Stack trace: $stackTrace');
          debugPrint('❌ Data: $data');
        }
      }
      
      debugPrint('✅ Total decks processed: ${decksList.length}');

      // Search flashcards
      final flashcardsData = await _firestoreRepo.searchFlashcards(query);
      final flashcardsList = flashcardsData.map((data) {
        // Handle createdAt - could be Timestamp or String (ISO8601)
        DateTime createdAt;
        if (data['createdAt'] == null) {
          createdAt = DateTime.now();
        } else if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is String) {
          try {
            createdAt = DateTime.parse(data['createdAt'] as String);
          } catch (e) {
            debugPrint('⚠️ Error parsing createdAt: $e');
            createdAt = DateTime.now();
          }
        } else {
          createdAt = DateTime.now();
        }

        // Handle updatedAt - could be Timestamp or String (ISO8601)
        DateTime updatedAt;
        if (data['updatedAt'] == null) {
          updatedAt = DateTime.now();
        } else if (data['updatedAt'] is Timestamp) {
          updatedAt = (data['updatedAt'] as Timestamp).toDate();
        } else if (data['updatedAt'] is String) {
          try {
            updatedAt = DateTime.parse(data['updatedAt'] as String);
          } catch (e) {
            debugPrint('⚠️ Error parsing updatedAt: $e');
            updatedAt = DateTime.now();
          }
        } else {
          updatedAt = DateTime.now();
        }

        return FlashcardModel(
          id: data['flashcardId'] ?? '',
          deckId: data['deckId'] ?? '',
          front: data['front'] ?? '',
          back: data['back'] ?? '',
          tags: List<String>.from(data['tags'] ?? []),
          createdAt: createdAt,
          updatedAt: updatedAt,
          reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
          isKnown: data['isKnown'] ?? false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _deckResults = decksList;
          _flashcardResults = flashcardsList;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error searching: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tìm kiếm: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DeckModel _convertToDeckModel(Map<String, dynamic> data) {
    // Handle createdAt - could be Timestamp or String (ISO8601)
    DateTime createdAt;
    if (data['createdAt'] == null) {
      createdAt = DateTime.now();
    } else if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      try {
        createdAt = DateTime.parse(data['createdAt'] as String);
      } catch (e) {
        debugPrint('⚠️ Error parsing deck createdAt: $e');
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }

    // Handle updatedAt - could be Timestamp or String (ISO8601)
    DateTime updatedAt;
    if (data['updatedAt'] == null) {
      updatedAt = DateTime.now();
    } else if (data['updatedAt'] is Timestamp) {
      updatedAt = (data['updatedAt'] as Timestamp).toDate();
    } else if (data['updatedAt'] is String) {
      try {
        updatedAt = DateTime.parse(data['updatedAt'] as String);
      } catch (e) {
        debugPrint('⚠️ Error parsing deck updatedAt: $e');
        updatedAt = DateTime.now();
      }
    } else {
      updatedAt = DateTime.now();
    }

    return DeckModel(
      id: data['deckId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      flashcardCount: (data['flashcardCount'] as num?)?.toInt() ?? 0,
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      favoriteCount: (data['favoriteCount'] as num?)?.toInt() ?? 0,
      isPublic: data['isPublic'] ?? false,
      isFavorite: false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm deck hoặc flashcard...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
            ),
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.collections_bookmark),
              text: 'Decks',
            ),
            Tab(
              icon: Icon(Icons.credit_card),
              text: 'Flashcards',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isSearching)
            const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDeckResults(),
                _buildFlashcardResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckResults() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nhập từ khóa để tìm kiếm deck',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_deckResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy deck nào',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thử tìm kiếm với từ khóa khác',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deckResults.length,
      itemBuilder: (context, index) {
        final deck = _deckResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.collections_bookmark,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              deck.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (deck.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    deck.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      deck.authorName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.credit_card, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${deck.flashcardCount} cards',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.deckDetail,
                arguments: deck.id,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFlashcardResults() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nhập từ khóa để tìm kiếm flashcard',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_flashcardResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy flashcard nào',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thử tìm kiếm với từ khóa khác',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _flashcardResults.length,
      itemBuilder: (context, index) {
        final flashcard = _flashcardResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                Icons.credit_card,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(
              flashcard.front,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              flashcard.back,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.deckDetail,
                                arguments: flashcard.deckId,
                              );
                            },
                            icon: const Icon(Icons.collections_bookmark, size: 18),
                            label: const Text('Xem Deck'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

