import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../../data/models/deck_model.dart';
import '../../routes/app_routes.dart';
import '../../../core/services/auth_service.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  List<DeckModel> _decks = [];
  bool _isLoading = true;
  String _selectedFilter = 'Tất cả';
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
      List<Map<String, dynamic>> decksData;
      final currentUserId = AuthService.currentUserId;
      
      debugPrint('📋 Loading decks with filter: $_selectedFilter');
      debugPrint('👤 Current user ID: $currentUserId');
      
      // Load decks based on filter
      if (_selectedFilter == 'Của tôi' && currentUserId != null) {
        debugPrint('🔍 Loading user decks...');
        decksData = await _firestoreRepo.getDecksByAuthor(currentUserId);
        debugPrint('✅ Loaded ${decksData.length} user decks');
      } else if (_selectedFilter == 'Yêu thích' && currentUserId != null) {
        debugPrint('🔍 Loading favorite decks...');
        decksData = await _firestoreRepo.getUserFavoriteDecks(currentUserId);
        debugPrint('✅ Loaded ${decksData.length} favorite decks');
      } else if (_selectedFilter == 'Tất cả') {
        debugPrint('🔍 Loading all visible decks (public + user decks)...');
        decksData = await _firestoreRepo.getAllVisibleDecks(userId: currentUserId, limit: 50);
        debugPrint('✅ Loaded ${decksData.length} visible decks');
      } else {
        // For "Công khai" filter, show all public decks (approved + pending)
        debugPrint('🔍 Loading public decks (including pending)...');
        decksData = await _firestoreRepo.getPublicDecks(limit: 50, includePending: true);
        debugPrint('✅ Loaded ${decksData.length} public decks');
      }
      
      // Convert to DeckModel and check favorite status
      final decksList = <DeckModel>[];
      for (var data in decksData) {
        final deck = _convertToDeckModel(data);
        bool isFavorite = false;
        if (currentUserId != null) {
          try {
            isFavorite = await _firestoreRepo.isDeckFavorited(currentUserId, deck.id);
          } catch (e) {
            // Error checking favorite, continue with false
            debugPrint('⚠️ Error checking favorite for deck ${deck.id}: $e');
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
      }
      
      debugPrint('✅ Converted ${decksList.length} decks to DeckModel');
      
      setState(() {
        _decks = decksList;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading decks: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      
      setState(() {
        _isLoading = false;
      });
      
      // Only show error if it's NOT an index-related error (fallback will handle it)
      if (mounted) {
        final isIndexError = e.toString().contains('index') || 
            e.toString().contains('FAILED_PRECONDITION') ||
            e.toString().contains('Index is being created');
        
        // Don't show snackbar for index errors - fallback query will handle it silently
        if (!isIndexError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi tải dữ liệu: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Just log to console, don't show to user
          debugPrint('ℹ️ Index is being created, using fallback query silently');
        }
      }
    }
  }

  DeckModel _convertToDeckModel(Map<String, dynamic> data) {
    return DeckModel(
      id: data['deckId'] ?? data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      flashcardCount: data['flashcardCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      favoriteCount: data['favoriteCount'] ?? 0,
      isPublic: data['isPublic'] ?? true,
      isFavorite: data['isFavorite'] ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : DateTime.now(),
    );
  }

  List<DeckModel> get _filteredDecks {
    var filtered = _decks;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered.where((deck) {
        return deck.name.toLowerCase().contains(lowerQuery) ||
            deck.description.toLowerCase().contains(lowerQuery);
      }).toList();
    }
    
    // Additional client-side filtering (already filtered by _loadDecks, but keep for consistency)
    if (_selectedFilter == 'Công khai') {
      filtered = filtered.where((deck) => deck.isPublic).toList();
    } else if (_selectedFilter == 'Yêu thích') {
      filtered = filtered.where((deck) => deck.isFavorite).toList();
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
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Tất cả'),
                  selected: _selectedFilter == 'Tất cả',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Tất cả';
                      });
                      _loadDecks();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Của tôi'),
                  selected: _selectedFilter == 'Của tôi',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Của tôi';
                      });
                      _loadDecks();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Công khai'),
                  selected: _selectedFilter == 'Công khai',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Công khai';
                      });
                      _loadDecks();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Yêu thích'),
                  selected: _selectedFilter == 'Yêu thích',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Yêu thích';
                      });
                      _loadDecks();
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
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
                            return _DeckCard(
                              deck: deck,
                              onFavoriteChanged: _loadDecks,
                              onDeleted: _loadDecks,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateDeckDialog();
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo Deck'),
      ),
    );
  }

  void _showCreateDeckDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPublic = false; // Default: private
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo Deck mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên deck',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quyền riêng tư',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<bool>(
                          title: const Text('Riêng tư'),
                          subtitle: const Text('Chỉ bạn có thể xem'),
                          value: false,
                          groupValue: isPublic,
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                isPublic = value;
                              });
                            }
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<bool>(
                          title: const Text('Công khai'),
                          subtitle: const Text('Mọi người có thể xem và học'),
                          value: true,
                          groupValue: isPublic,
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                isPublic = value;
                              });
                            }
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập tên deck'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                
                try {
                  final currentUser = AuthService.currentUser;
                  final currentUserId = AuthService.currentUserId;
                  if (currentUser != null && currentUserId != null) {
                    final deckId = await _firestoreRepo.createDeck({
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                      'authorId': currentUserId,
                      'authorName': currentUser['name'] ?? 'User',
                      'isPublic': isPublic,
                      'status': isPublic ? 'public' : 'private',
                    });
                  
                  if (!mounted) return;
                  navigator.pop();
                  
                  // Switch to "Của tôi" filter to show the newly created deck
                  setState(() {
                    _selectedFilter = 'Của tôi';
                  });
                  
                  await _loadDecks();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Đã tạo deck mới'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Navigate to deck detail to add flashcards
                    navigator.pushNamed(
                      AppRoutes.deckDetail,
                      arguments: deckId,
                    );
                  }
                }
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Lỗi: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
      ),
    );
  }
}

class _DeckCard extends StatefulWidget {
  final DeckModel deck;
  final VoidCallback? onFavoriteChanged;
  final VoidCallback? onDeleted;

  const _DeckCard({
    required this.deck,
    this.onFavoriteChanged,
    this.onDeleted,
  });

  @override
  State<_DeckCard> createState() => _DeckCardState();
}

class _DeckCardState extends State<_DeckCard> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  bool _isFavorite = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.deck.isFavorite;
    _checkOwnership();
  }

  void _checkOwnership() {
    final currentUserId = AuthService.currentUserId;
    _isOwner = currentUserId != null && widget.deck.authorId == currentUserId;
  }

  Future<void> _toggleFavorite() async {
    final currentUserId = AuthService.currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để yêu thích deck'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final newFavoriteStatus = await _firestoreRepo.toggleFavoriteDeck(
        currentUserId,
        widget.deck.id,
      );

      setState(() {
        _isFavorite = newFavoriteStatus;
      });

      if (widget.onFavoriteChanged != null) {
        widget.onFavoriteChanged!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newFavoriteStatus
                  ? 'Đã thêm vào yêu thích'
                  : 'Đã bỏ yêu thích',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa deck này? Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreRepo.deleteDeck(widget.deck.id);
        if (widget.onDeleted != null) {
          widget.onDeleted!();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa deck'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.deckDetail,
            arguments: widget.deck.id,
          ).then((_) {
            // Reload when coming back from detail screen
            if (widget.onFavoriteChanged != null) {
              widget.onFavoriteChanged!();
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.deck.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (_isOwner)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _showDeleteDialog();
                                  } else if (value == 'toggle_public') {
                                    _togglePublicStatus();
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'toggle_public',
                                    child: Row(
                                      children: [
                                        Icon(
                                          widget.deck.isPublic
                                              ? Icons.public_off
                                              : Icons.public,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.deck.isPublic
                                              ? 'Ẩn công khai'
                                              : 'Công khai',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Xóa deck', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.deck.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red : null,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.credit_card,
                    label: '${widget.deck.flashcardCount} thẻ',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.person,
                    label: widget.deck.authorName,
                  ),
                  const Spacer(),
                  if (widget.deck.isPublic)
                    _InfoChip(
                      icon: Icons.public,
                      label: 'Công khai',
                    ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.visibility,
                    label: '${widget.deck.viewCount}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _togglePublicStatus() async {
    try {
      final newPublicStatus = !widget.deck.isPublic;
      await _firestoreRepo.updateDeck(widget.deck.id, {
        'isPublic': newPublicStatus,
      });

      if (widget.onFavoriteChanged != null) {
        widget.onFavoriteChanged!();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newPublicStatus
                  ? 'Đã công khai deck'
                  : 'Đã ẩn deck khỏi công khai',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
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
            'Chưa có deck nào',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tạo deck đầu tiên để bắt đầu học tập',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
                Navigator.of(context).pop();
                // This will be handled by parent widget
            },
            icon: const Icon(Icons.add),
            label: const Text('Tạo Deck mới'),
          ),
        ],
      ),
    );
  }
}
