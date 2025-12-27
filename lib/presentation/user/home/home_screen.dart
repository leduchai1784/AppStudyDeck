import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../routes/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../../data/models/deck_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  List<DeckModel> _recentDecks = [];
  int _totalDecks = 0;
  int _totalFlashcards = 0;
  int _todayFlashcardsStudied = 0;
  int _userScore = 0;
  int _unreadNotificationsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadNotificationsCount();
  }

  Future<void> _loadUnreadNotificationsCount() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;

    try {
      final count = await _firestoreRepo.getUnreadNotificationsCount(userId);
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading unread notifications count: $e');
    }
  }

  Future<void> _loadTodayStudyData(String userId) async {
    try {
      debugPrint('📊 Loading today\'s study data for: $userId');
      final studySessions = await _firestoreRepo.getUserStudySessions(userId);
      
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      int todayFlashcards = 0;
      
      for (var session in studySessions) {
        final startTimeStr = session['startTime'] as String?;
        if (startTimeStr == null || startTimeStr.isEmpty) continue;
        
        try {
          final startTime = DateTime.parse(startTimeStr);
          if (startTime.isAfter(todayStart) || startTime.isAtSameMomentAs(todayStart)) {
            final flashcardsStudied = (session['flashcardsStudied'] as num?)?.toInt() ?? 0;
            todayFlashcards += flashcardsStudied;
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing startTime: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _todayFlashcardsStudied = todayFlashcards;
        });
      }
      
      debugPrint('✅ Today\'s flashcards studied: $todayFlashcards');
    } catch (e) {
      debugPrint('⚠️ Error loading today\'s study data: $e');
    }
  }

  Future<void> _calculateUserScore(String userId) async {
    try {
      debugPrint('📊 Calculating user score for: $userId');
      
      int score = 0;
      Set<String> completedDeckIds = {};
      
      // Load flashcard progress to count known flashcards and completed decks
      try {
        final flashcardProgressList = await _firestoreRepo.getAllUserFlashcardProgress(userId);
        debugPrint('📊 Found ${flashcardProgressList.length} flashcard progress records for score calculation');
        
        // Group flashcard progress by deckId
        Map<String, List<Map<String, dynamic>>> deckFlashcards = {};
        for (var progress in flashcardProgressList) {
          final deckId = progress['deckId'] as String?;
          if (deckId != null && deckId.isNotEmpty) {
            if (!deckFlashcards.containsKey(deckId)) {
              deckFlashcards[deckId] = [];
            }
            deckFlashcards[deckId]!.add(progress);
          }
        }
        
        debugPrint('📊 Found ${deckFlashcards.length} decks with flashcard progress');
        
        // Calculate score for each deck
        for (var deckId in deckFlashcards.keys) {
          try {
            final deckData = await _firestoreRepo.getDeckById(deckId);
            final totalFlashcards = (deckData?['flashcardCount'] as num?)?.toInt() ?? 0;
            final deckFlashcardProgress = deckFlashcards[deckId]!;
            
            // Count known flashcards in this deck
            int knownFlashcards = 0;
            for (var progress in deckFlashcardProgress) {
              if (progress['isKnown'] == true) {
                knownFlashcards++;
              }
            }
            
            // 10 điểm cho mỗi flashcard đã thuộc
            score += knownFlashcards * 10;
            
            // Check if deck is completed (all flashcards studied)
            final uniqueFlashcardsStudied = deckFlashcardProgress.length;
            final isCompleted = totalFlashcards > 0 && uniqueFlashcardsStudied >= totalFlashcards;
            
            if (isCompleted) {
              completedDeckIds.add(deckId);
              // 50 điểm bonus cho mỗi deck hoàn thành
              score += 50;
              debugPrint('   ✅ Deck $deckId: completed (+50 bonus), known flashcards: $knownFlashcards (+${knownFlashcards * 10})');
            } else {
              debugPrint('   📝 Deck $deckId: known flashcards: $knownFlashcards (+${knownFlashcards * 10}), not completed yet');
            }
          } catch (e) {
            debugPrint('⚠️ Error processing deck $deckId for score: $e');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error loading flashcard progress for score: $e');
        
        // Fallback: try to get from deck progress
        try {
          final progressList = await _firestoreRepo.getAllUserDeckProgress(userId);
          for (var progress in progressList) {
            final isCompleted = progress['isCompleted'] == true;
            if (isCompleted) {
              score += 50; // 50 điểm cho mỗi deck hoàn thành
            }
            
            final knownFlashcards = (progress['knownFlashcards'] as num?)?.toInt() ?? 0;
            score += knownFlashcards * 10; // 10 điểm cho mỗi flashcard đã thuộc
          }
        } catch (e2) {
          debugPrint('⚠️ Error loading deck progress for score fallback: $e2');
        }
      }
      
      if (mounted) {
        setState(() {
          _userScore = score;
        });
      }
      
      debugPrint('✅ User score calculated: $score');
      debugPrint('   - Completed decks: ${completedDeckIds.length}');
      debugPrint('   - Score breakdown:');
      debugPrint('     • 10 points per known flashcard');
      debugPrint('     • 50 bonus points per completed deck');
    } catch (e) {
      debugPrint('⚠️ Error calculating user score: $e');
    }
  }

  Widget _buildAvatarIcon() {
    final currentUser = AuthService.currentUser;
    final avatarUrl = currentUser?['avatarUrl'] ?? currentUser?['photoUrl'];
    final userName = currentUser?['name'] ?? 'User';
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      debugPrint('🏠 Loading home screen data...');
      final currentUserId = AuthService.currentUserId;
      
      if (currentUserId == null) {
        debugPrint('⚠️ User not logged in, cannot load data');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Load user's own decks only (for statistics)
      final userDecksData = await _firestoreRepo.getDecksByAuthor(currentUserId);
      debugPrint('✅ Loaded ${userDecksData.length} user decks');
      
      // Calculate statistics from user's own decks only
      final userDecksList = <DeckModel>[];
      int totalUserFlashcards = 0;
      
      for (var data in userDecksData) {
        final deck = _convertToDeckModel(data);
        userDecksList.add(deck);
        totalUserFlashcards += deck.flashcardCount;
      }
      
      // Load recent visible decks (public + user's own) for display
      final visibleDecksData = await _firestoreRepo.getAllVisibleDecks(
        userId: currentUserId,
        limit: 20,
      );
      
      debugPrint('✅ Loaded ${visibleDecksData.length} visible decks');
      
      final recentDecksList = <DeckModel>[];
      
      // Get user's favorite status for each deck
      for (var data in visibleDecksData) {
        final deck = _convertToDeckModel(data);
        bool isFavorite = false;
        try {
          isFavorite = await _firestoreRepo.isDeckFavorited(currentUserId, deck.id);
        } catch (e) {
          debugPrint('⚠️ Error checking favorite status: $e');
        }
        
        recentDecksList.add(DeckModel(
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
      
      debugPrint('✅ Converted ${recentDecksList.length} decks to DeckModel');
      
      // Load today's study data
      await _loadTodayStudyData(currentUserId);
      
      // Calculate user score
      await _calculateUserScore(currentUserId);
      
      setState(() {
        // Get 3 most recent decks (from visible decks)
        _recentDecks = recentDecksList.take(3).toList();
        // Statistics: only count user's own decks
        _totalDecks = userDecksList.length;
        _totalFlashcards = totalUserFlashcards;
        _isLoading = false;
      });
      
      debugPrint('✅ Home screen data loaded:');
      debugPrint('   - Recent decks: ${_recentDecks.length}');
      debugPrint('   - User total decks: $_totalDecks');
      debugPrint('   - User total flashcards: $_totalFlashcards');
      debugPrint('   - Today flashcards studied: $_todayFlashcardsStudied');
      debugPrint('   - User score: $_userScore');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading home data: $e');
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
                  autofocus: true,
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
                  
                  // Reload data to update statistics
                  await _loadData();
                  
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
                navigator.pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Deck'),
        automaticallyImplyLeading: false, // Bỏ dấu mũi tên quay lại
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.search);
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.notifications).then((_) {
                    // Reload unread count when returning from notifications screen
                    _loadUnreadNotificationsCount();
                  });
                },
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationsCount > 99 ? '99+' : '$_unreadNotificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settings);
            },
            icon: _buildAvatarIcon(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào!',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sẵn sàng học tập hôm nay?',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Quick stats
            Text(
              'Thống kê',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.collections_bookmark,
                    label: 'Tổng Deck',
                    value: '$_totalDecks',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.credit_card,
                    label: 'Tổng Flashcard',
                    value: '$_totalFlashcards',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.trending_up,
                    label: 'Đã học hôm nay',
                    value: '$_todayFlashcardsStudied',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.star,
                    label: 'Điểm số',
                    value: '$_userScore',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Quick actions
            Text(
              'Thao tác nhanh',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _QuickActionCard(
                  icon: Icons.play_circle_filled,
                  label: 'Bắt đầu học',
                  color: Colors.blue,
                  onTap: () {
                    // TODO: Navigate to study screen with deck selection
                    Navigator.pushNamed(context, AppRoutes.deckList);
                  },
                ),
                _QuickActionCard(
                  icon: Icons.add_circle,
                  label: 'Tạo Deck mới',
                  color: Colors.green,
                  onTap: () {
                    _showCreateDeckDialog();
                  },
                ),
                _QuickActionCard(
                  icon: Icons.collections,
                  label: 'Quản lý Deck',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.deckList);
                  },
                ),
                _QuickActionCard(
                  icon: Icons.bar_chart,
                  label: 'Thống kê',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.statistics);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Recent decks
            Text(
              'Deck gần đây',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recentDecks.isEmpty
                    ? _EmptyState(
                        icon: Icons.collections_bookmark_outlined,
                        message: 'Chưa có deck nào',
                        actionLabel: 'Tạo deck đầu tiên',
                        onAction: () {
                          Navigator.pushNamed(context, AppRoutes.deckList);
                        },
                      )
                    : Column(
                        children: _recentDecks.map((deck) {
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
                              title: Text(
                                deck.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${deck.flashcardCount} flashcard • ${deck.authorName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.deckDetail,
                                  arguments: deck.id,
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

