import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../routes/app_routes.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/deck_model.dart';
import '../../../data/models/flashcard_model.dart';

class DeckDetailScreen extends StatefulWidget {
  final String deckId;
  
  const DeckDetailScreen({
    super.key,
    required this.deckId,
  });

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  DeckModel? _deck;
  List<FlashcardModel> _flashcards = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadDeckData();
  }

  Future<void> _loadDeckData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔍 Loading deck data for deckId: ${widget.deckId}');
      
      // Load deck
      final deckData = await _firestoreRepo.getDeckById(widget.deckId);
      if (deckData == null) {
        throw Exception('Deck not found');
      }
      
      // Check if current user is owner
      final currentUserId = AuthService.currentUserId;
      _isOwner = currentUserId != null && deckData['authorId'] == currentUserId;
      
      // Check favorite status
      if (currentUserId != null) {
        _isFavorite = await _firestoreRepo.isDeckFavorited(currentUserId, widget.deckId);
      }
      
      // Convert to DeckModel
      _deck = _convertToDeckModel(deckData);
      
      // Load flashcards
      final flashcardsData = await _firestoreRepo.getFlashcardsByDeck(widget.deckId);
      _flashcards = flashcardsData.map((data) => _convertToFlashcardModel(data)).toList();
      
      // Increment view count if not owner
      if (!_isOwner) {
        try {
          await _firestoreRepo.incrementDeckViewCount(widget.deckId);
        } catch (e) {
          debugPrint('⚠️ Error incrementing view count: $e');
        }
      }
      
      setState(() {
        _isLoading = false;
      });
      
      debugPrint('✅ Deck data loaded successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading deck data: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
      isFavorite: _isFavorite,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : DateTime.now(),
    );
  }

  FlashcardModel _convertToFlashcardModel(Map<String, dynamic> data) {
    return FlashcardModel(
      id: data['flashcardId'] ?? data['id'] ?? '',
      deckId: data['deckId'] ?? '',
      front: data['front'] ?? '',
      back: data['back'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : DateTime.now(),
      reviewCount: data['reviewCount'] ?? 0,
      isKnown: data['isKnown'] ?? false,
    );
  }

  void _showEditDeckDialog() {
    final nameController = TextEditingController(text: _deck?.name);
    final descController = TextEditingController(text: _deck?.description);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa Deck'),
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
              try {
                await _firestoreRepo.updateDeck(widget.deckId, {
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                });
                Navigator.of(context).pop();
                await _loadDeckData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã cập nhật deck'),
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
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showAddFlashcardMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.blue),
              title: const Text('Thêm Flashcard'),
              subtitle: const Text('Thêm một flashcard mới'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(
                  context,
                  AppRoutes.flashcardEdit,
                  arguments: {
                    'deckId': widget.deckId,
                    'flashcardId': null,
                  },
                ).then((_) {
                  _loadDeckData();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.purple),
              title: const Text('Thêm Flashcard Hàng Loạt'),
              subtitle: const Text('Thêm nhiều flashcard cùng lúc'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(
                  context,
                  AppRoutes.flashcardBulkAdd,
                  arguments: widget.deckId,
                ).then((result) {
                  if (result == true) {
                    _loadDeckData();
                  }
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.report, color: Colors.red),
            SizedBox(width: 8),
            Text('Báo cáo deck'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bạn muốn báo cáo deck này vì lý do gì?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Nhập lý do báo cáo (nội dung sai, spam, không phù hợp, ...)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Admin sẽ xem xét báo cáo và có thể ẩn deck nếu vi phạm.',
                        style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                      ),
                    ),
                  ],
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
              if (reasonController.text.trim().isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập lý do báo cáo'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final currentUser = AuthService.currentUser;
              final currentUserId = AuthService.currentUserId;
              
              if (currentUser == null || currentUserId == null) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng đăng nhập'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              try {
                await _firestoreRepo.reportDeck(
                  widget.deckId,
                  currentUserId,
                  currentUser['name'] ?? 'User',
                  reasonController.text.trim(),
                );
                
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã gửi báo cáo. Cảm ơn bạn đã phản hồi!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi gửi báo cáo: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
  }

  void _showMenuDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tùy chọn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Favorite options (for all users)
            if (_isFavorite)
              ListTile(
                leading: const Icon(Icons.favorite_border, color: Colors.red),
                title: const Text('Bỏ yêu thích'),
                onTap: () {
                  Navigator.of(context).pop();
                  _removeFavorite();
                },
              ),
            // Owner options
            if (_isOwner) ...[
              const Divider(),
              ListTile(
                leading: Icon(
                  _deck?.isPublic == true ? Icons.public_off : Icons.public,
                ),
                title: Text(_deck?.isPublic == true ? 'Ẩn công khai' : 'Công khai'),
                subtitle: Text(
                  _deck?.isPublic == true 
                      ? 'Chỉ bạn mới thấy deck này'
                      : 'Mọi người có thể thấy deck này',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _togglePublicStatus();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Xóa deck', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteConfirmDialog();
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFavorite() async {
    if (!_isFavorite) {
      debugPrint('⚠️ Deck is not favorited, cannot remove');
      return;
    }
    
    final currentUserId = AuthService.currentUserId;
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      debugPrint('🔴 Removing favorite for deck: ${widget.deckId}');
      
      // Toggle favorite (will remove if already favorited)
      final newFavoriteStatus = await _firestoreRepo.toggleFavoriteDeck(
        currentUserId,
        widget.deckId,
      );
      
      debugPrint('✅ Favorite toggled, new status: $newFavoriteStatus');
      
      // Reload deck data to get updated favorite count
      await _loadDeckData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã bỏ yêu thích'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error removing favorite: $e');
      debugPrint('❌ Stack trace: $stackTrace');
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

  Future<void> _togglePublicStatus() async {
    if (_deck == null) return;
    
    try {
      final newPublicStatus = !(_deck!.isPublic);
      await _firestoreRepo.updateDeck(widget.deckId, {
        'isPublic': newPublicStatus,
      });
      
      await _loadDeckData();
      
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

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa deck này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _firestoreRepo.deleteDeck(widget.deckId);
                if (mounted) {
                  Navigator.of(context).pop(); // Close confirm dialog
                  Navigator.of(context).pop(); // Go back to previous screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa deck'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final currentUserId = AuthService.currentUserId;
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để yêu thích deck'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    try {
      debugPrint('❤️ Toggling favorite for deck: ${widget.deckId}');
      debugPrint('❤️ Current favorite status: $_isFavorite');
      
      final newFavoriteStatus = await _firestoreRepo.toggleFavoriteDeck(
        currentUserId,
        widget.deckId,
      );
      
      debugPrint('✅ Favorite toggled, new status: $newFavoriteStatus');
      
      // Reload deck data to get updated favorite count and status
      await _loadDeckData();
      
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
    } catch (e, stackTrace) {
      debugPrint('❌ Error toggling favorite: $e');
      debugPrint('❌ Stack trace: $stackTrace');
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết Deck')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_deck == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết Deck')),
        body: const Center(
          child: Text('Không tìm thấy deck'),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                _deck!.name,
                textAlign: TextAlign.center,
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.collections_bookmark,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _deck!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : null,
                ),
                onPressed: _toggleFavorite,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'report') {
                    _showReportDialog();
                  } else if (value == 'menu') {
                    _showMenuDialog();
                  }
                },
                itemBuilder: (context) => [
                  if (!_isOwner)
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.report, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Báo cáo deck'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'menu',
                    child: Row(
                      children: [
                        Icon(Icons.more_vert),
                        SizedBox(width: 8),
                        Text('Tùy chọn'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Deck info
                  Card(
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
                                    Text(
                                      _deck!.name,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _deck!.description,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _InfoItem(
                                icon: Icons.credit_card,
                                label: 'Flashcard',
                                value: '${_deck!.flashcardCount}',
                              ),
                              _InfoItem(
                                icon: Icons.person,
                                label: 'Tác giả',
                                value: _deck!.authorName,
                              ),
                              _InfoItem(
                                icon: Icons.visibility,
                                label: 'Lượt xem',
                                value: '${_deck!.viewCount}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.study,
                              arguments: widget.deckId,
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Bắt đầu học'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.study,
                              arguments: widget.deckId,
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Ôn tập'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isOwner) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _showEditDeckDialog();
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Chỉnh sửa'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _showMenuDialog();
                            },
                            icon: const Icon(Icons.more_vert),
                            label: const Text('Tùy chọn'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  
                  // Flashcard list
                  Text(
                    'Danh sách Flashcard (${_flashcards.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _flashcards.isEmpty
                      ? _EmptyFlashcardList(
                          deckId: widget.deckId,
                          onAddFlashcard: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.flashcardEdit,
                              arguments: {
                                'deckId': widget.deckId,
                                'flashcardId': null,
                              },
                            ).then((_) {
                              _loadDeckData();
                            });
                          },
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _flashcards.length,
                          itemBuilder: (context, index) {
                            final flashcard = _flashcards[index];
                            return _FlashcardCard(
                              flashcard: flashcard,
                              onEdit: () async {
                                await Navigator.pushNamed(
                                  context,
                                  AppRoutes.flashcardEdit,
                                  arguments: {
                                    'deckId': widget.deckId,
                                    'flashcardId': flashcard.id,
                                  },
                                );
                                _loadDeckData();
                              },
                              onDelete: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Xác nhận xóa'),
                                    content: const Text('Bạn có chắc chắn muốn xóa flashcard này?'),
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
                                    await _firestoreRepo.deleteFlashcard(
                                      flashcard.id,
                                      widget.deckId,
                                    );
                                    _loadDeckData();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Đã xóa flashcard'),
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
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isOwner
          ? FloatingActionButton(
              onPressed: () {
                _showAddFlashcardMenu(context);
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FlashcardCard extends StatelessWidget {
  final FlashcardModel flashcard;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _FlashcardCard({
    required this.flashcard,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            '${flashcard.front[0].toUpperCase()}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          flashcard.front,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Nhấn để xem đáp án',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility_off, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Mặt sau:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  flashcard.back,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (flashcard.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: flashcard.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        labelStyle: const TextStyle(fontSize: 12),
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ],
                if (onEdit != null || onDelete != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onEdit != null)
                        TextButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Sửa'),
                        ),
                      if (onDelete != null)
                        TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Xóa'),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFlashcardList extends StatelessWidget {
  final String deckId;
  final VoidCallback? onAddFlashcard;

  const _EmptyFlashcardList({
    required this.deckId,
    this.onAddFlashcard,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có flashcard nào',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAddFlashcard ?? () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.flashcardEdit,
                  arguments: {
                    'deckId': deckId,
                    'flashcardId': null,
                  },
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm Flashcard'),
            ),
          ],
        ),
      ),
    );
  }
}
