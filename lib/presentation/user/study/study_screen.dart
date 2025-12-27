import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../../data/models/flashcard_model.dart';
import '../../../core/services/auth_service.dart';

class StudyScreen extends StatefulWidget {
  final String deckId;
  
  const StudyScreen({
    super.key,
    required this.deckId,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final _firestoreRepo = FirestoreRepository();
  bool _isFlipped = false;
  int _currentIndex = 0;
  List<FlashcardModel> _flashcards = [];
  bool _isLoading = true;
  DateTime? _sessionStartTime;
  int _flashcardsStudied = 0;
  int _flashcardsKnown = 0;
  int _flashcardsUnknown = 0;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _loadFlashcards();
  }

  @override
  void dispose() {
    // Save session when leaving (if user didn't complete all cards)
    if (_flashcardsStudied > 0 && _sessionStartTime != null) {
      _saveStudySession();
      _updateDeckProgress();
    }
    super.dispose();
  }

  Future<void> _loadFlashcards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔄 Loading flashcards for deck: ${widget.deckId}');
      
      // Check authentication
      final userId = AuthService.currentUserId;
      if (userId == null) {
        throw Exception('User must be authenticated to study');
      }
      
      // Load flashcards from Firestore
      final flashcardsData = await _firestoreRepo.getFlashcardsByDeck(widget.deckId);
      
      if (flashcardsData.isEmpty) {
        debugPrint('⚠️ No flashcards found in deck');
        setState(() {
          _flashcards = [];
          _isLoading = false;
        });
        return;
      }
      
      // Convert to FlashcardModel
      final flashcards = flashcardsData.map((data) {
        return FlashcardModel(
          id: data['flashcardId'] ?? data['id'] ?? '',
          deckId: data['deckId'] ?? widget.deckId,
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
      }).toList();
      
      debugPrint('✅ Loaded ${flashcards.length} flashcards');
      
      setState(() {
        _flashcards = flashcards;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading flashcards: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải flashcard: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int get _totalCards => _flashcards.length;
  FlashcardModel? get _currentCard => 
      _currentIndex < _flashcards.length ? _flashcards[_currentIndex] : null;

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _nextCard() {
    if (_currentIndex < _totalCards - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      // Finished all cards
      _showCompletionDialog();
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  Future<void> _markAsKnown() async {
    if (_currentCard == null) return;
    
    final userId = AuthService.currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để lưu tiến độ'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      _nextCard();
      return;
    }
    
    try {
      _flashcardsStudied++;
      _flashcardsKnown++;
      
      // Update user flashcard progress
      await _firestoreRepo.updateUserFlashcardProgress(
        userId: userId,
        flashcardId: _currentCard!.id,
        deckId: widget.deckId,
        progressData: {
          'isKnown': true,
          'reviewCount': FieldValue.increment(1),
          'lastReviewDate': FieldValue.serverTimestamp(),
          'correctStreak': FieldValue.increment(1),
          'incorrectStreak': 0,
        },
      );
      
      debugPrint('✅ Marked flashcard ${_currentCard!.id} as known');
    } catch (e) {
      debugPrint('⚠️ Error marking flashcard as known: $e');
      // Continue anyway
    }
    
    _nextCard();
  }

  Future<void> _markAsUnknown() async {
    if (_currentCard == null) return;
    
    final userId = AuthService.currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để lưu tiến độ'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      _nextCard();
      return;
    }
    
    try {
      _flashcardsStudied++;
      _flashcardsUnknown++;
      
      // Update user flashcard progress
      await _firestoreRepo.updateUserFlashcardProgress(
        userId: userId,
        flashcardId: _currentCard!.id,
        deckId: widget.deckId,
        progressData: {
          'isKnown': false,
          'reviewCount': FieldValue.increment(1),
          'lastReviewDate': FieldValue.serverTimestamp(),
          'correctStreak': 0,
          'incorrectStreak': FieldValue.increment(1),
        },
      );
      
      debugPrint('✅ Marked flashcard ${_currentCard!.id} as unknown');
    } catch (e) {
      debugPrint('⚠️ Error marking flashcard as unknown: $e');
      // Continue anyway
    }
    
    _nextCard();
  }

  Future<void> _saveStudySession() async {
    final userId = AuthService.currentUserId;
    if (userId == null || _sessionStartTime == null) return;
    
    try {
      final endTime = DateTime.now();
      final duration = endTime.difference(_sessionStartTime!).inMinutes;
      
      await _firestoreRepo.createStudySession({
        'userId': userId,
        'deckId': widget.deckId,
        'startTime': _sessionStartTime!,
        'endTime': endTime,
        'duration': duration,
        'flashcardsStudied': _flashcardsStudied,
        'flashcardsKnown': _flashcardsKnown,
        'flashcardsUnknown': _flashcardsUnknown,
      });
      
      debugPrint('✅ Study session saved');
    } catch (e) {
      debugPrint('⚠️ Error saving study session: $e');
      // Don't throw - session is optional
    }
  }

  Future<void> _updateDeckProgress() async {
    final userId = AuthService.currentUserId;
    if (userId == null || _flashcardsStudied == 0) return;
    
    try {
      // Get current deck progress
      final currentProgress = await _firestoreRepo.getUserDeckProgress(userId, widget.deckId);
      
      // Calculate new progress
      final totalFlashcards = _flashcards.length;
      final currentStudied = currentProgress?['studiedFlashcards'] ?? 0;
      final currentKnown = currentProgress?['knownFlashcards'] ?? 0;
      final currentUnknown = currentProgress?['unknownFlashcards'] ?? 0;
      
      // Note: studiedFlashcards is the total count of reviews, not unique flashcards
      // So we increment it by the number of flashcards studied in this session
      final newStudiedFlashcards = currentStudied + _flashcardsStudied;
      final newKnownFlashcards = currentKnown + _flashcardsKnown;
      final newUnknownFlashcards = currentUnknown + _flashcardsUnknown;
      
      // Count unique flashcards that have been reviewed at least once
      // This gives us the actual number of flashcards studied (not review count)
      int uniqueFlashcardsStudied = 0;
      int uniqueKnownFlashcards = 0;
      
      try {
        final flashcardProgressList = await _firestoreRepo.getAllUserFlashcardProgress(userId);
        final deckFlashcardProgress = flashcardProgressList
            .where((progress) => progress['deckId'] == widget.deckId)
            .toList();
        
        uniqueFlashcardsStudied = deckFlashcardProgress.length;
        uniqueKnownFlashcards = deckFlashcardProgress
            .where((progress) => progress['isKnown'] == true)
            .length;
        
        debugPrint('📊 Unique flashcards studied: $uniqueFlashcardsStudied/$totalFlashcards');
        debugPrint('📊 Unique known flashcards: $uniqueKnownFlashcards');
      } catch (e) {
        debugPrint('⚠️ Error counting unique flashcards: $e');
        // Fallback: use studiedFlashcards count if we can't get unique count
        uniqueFlashcardsStudied = newStudiedFlashcards;
      }
      
      // Calculate completion percentage based on unique flashcards studied
      final completionPercentage = totalFlashcards > 0 
          ? ((uniqueFlashcardsStudied / totalFlashcards) * 100).clamp(0, 100)
          : 0;
      
      // A deck is completed when ALL unique flashcards have been reviewed at least once
      final isCompleted = uniqueFlashcardsStudied >= totalFlashcards && totalFlashcards > 0;
      
      // Update progress
      await _firestoreRepo.updateUserDeckProgress(
        userId: userId,
        deckId: widget.deckId,
        progressData: {
          'totalFlashcards': totalFlashcards,
          'studiedFlashcards': newStudiedFlashcards, // Total review count
          'knownFlashcards': uniqueKnownFlashcards > 0 ? uniqueKnownFlashcards : newKnownFlashcards,
          'unknownFlashcards': newUnknownFlashcards,
          'lastStudyDate': FieldValue.serverTimestamp(),
          'firstStudyDate': currentProgress?['firstStudyDate'] ?? FieldValue.serverTimestamp(),
          'completionPercentage': completionPercentage,
          'isCompleted': isCompleted,
        },
      );
      
      debugPrint('✅ Deck progress updated:');
      debugPrint('   - Unique flashcards studied: $uniqueFlashcardsStudied/$totalFlashcards');
      debugPrint('   - Total reviews: $newStudiedFlashcards');
      debugPrint('   - Completion: ${completionPercentage.toStringAsFixed(1)}%');
      debugPrint('   - Is completed: $isCompleted');
    } catch (e) {
      debugPrint('⚠️ Error updating deck progress: $e');
      // Don't throw - progress update is optional
    }
  }

  void _showCompletionDialog() async {
    // Save study session and update progress before showing dialog
    await _saveStudySession();
    await _updateDeckProgress();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hoàn thành!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn đã học xong tất cả $_totalCards flashcard trong deck này.'),
            const SizedBox(height: 16),
            Text('📊 Thống kê:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('• Đã học: $_flashcardsStudied'),
            Text('• Đã biết: $_flashcardsKnown'),
            Text('• Chưa biết: $_flashcardsUnknown'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back
            },
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              setState(() {
                _currentIndex = 0;
                _isFlipped = false;
                _flashcardsStudied = 0;
                _flashcardsKnown = 0;
                _flashcardsUnknown = 0;
                _sessionStartTime = DateTime.now();
              });
            },
            child: const Text('Học lại'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Học tập'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_totalCards == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Học tập'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Deck này chưa có flashcard nào',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thêm flashcard để bắt đầu học tập',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final card = _currentCard!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Học tập (${_currentIndex + 1}/$_totalCards)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              // Save session before leaving
              if (_flashcardsStudied > 0 && _sessionStartTime != null) {
                await _saveStudySession();
                await _updateDeckProgress();
              }
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _totalCards,
            minHeight: 4,
          ),
          
          // Flashcard
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _flipCard,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  width: double.infinity,
                  child: Card(
                    elevation: 8,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_isFlipped),
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: _isFlipped
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.visibility_off,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Mặt sau',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      card.back,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.visibility,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Mặt trước',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      card.front,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentIndex > 0 ? _previousCard : null,
                ),
                TextButton.icon(
                  onPressed: _flipCard,
                  icon: Icon(_isFlipped ? Icons.rotate_left : Icons.rotate_right),
                  label: Text(_isFlipped ? 'Xem mặt trước' : 'Xem mặt sau'),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _currentIndex < _totalCards - 1 ? _nextCard : null,
                ),
              ],
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _markAsUnknown,
                    icon: const Icon(Icons.close),
                    label: const Text('Chưa biết'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _markAsKnown,
                    icon: const Icon(Icons.check),
                    label: const Text('Đã biết'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
