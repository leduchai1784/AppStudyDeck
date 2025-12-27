import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/datasources/firestore_repository.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  
  // Calculated statistics
  int _totalDecks = 0;
  int _totalFlashcards = 0;
  int _totalDecksStudied = 0;
  int _totalFlashcardsStudied = 0;
  int _totalStudyTimeMinutes = 0;
  int _currentStreak = 0;
  int _favoriteDecksCount = 0;
  
  // Today's statistics
  int _todayFlashcardsStudied = 0;
  int _todayStudyTimeMinutes = 0;
  int _todayDecksStudied = 0;
  
  // Week statistics
  int _weekFlashcardsStudied = 0;
  int _weekStudyTimeMinutes = 0;
  int _weekDecksStudied = 0;
  
  // Month statistics
  int _monthFlashcardsStudied = 0;
  int _monthStudyTimeMinutes = 0;
  int _monthDecksStudied = 0;
  
  // Additional statistics
  int _totalKnownFlashcards = 0;
  int _totalCompletedDecks = 0;
  double _averageStudyTimePerSession = 0.0;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUserId = AuthService.currentUserId;
      if (currentUserId == null) {
        debugPrint('⚠️ User not logged in');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 1. User statistics will be calculated from actual data (deck progress, study sessions, etc.)

      // 2. Load user's own decks to count total decks and flashcards
      debugPrint('📊 Loading user decks for: $currentUserId');
      final userDecks = await _firestoreRepo.getDecksByAuthor(currentUserId);
      _totalDecks = userDecks.length;
      _totalFlashcards = userDecks.fold(0, (sum, deck) {
        return sum + ((deck['flashcardCount'] as num?)?.toInt() ?? 0);
      });
      debugPrint('📊 User has $_totalDecks decks with $_totalFlashcards flashcards');

      // 3. Load favorite decks count
      try {
        debugPrint('📊 Loading favorite decks for: $currentUserId');
        final favoriteDecks = await _firestoreRepo.getUserFavoriteDecks(currentUserId);
        _favoriteDecksCount = favoriteDecks.length;
        debugPrint('📊 User has $_favoriteDecksCount favorite decks');
      } catch (e) {
        debugPrint('⚠️ Error loading favorite decks: $e');
      }

      // 4. Load user deck progress to calculate statistics
      int totalKnownFlashcards = 0;
      int totalStudiedFlashcards = 0;
      int totalCompletedDecks = 0;
      int maxStreak = 0;
      Set<String> studiedDeckIds = {};
      
      try {
        debugPrint('📊 Loading deck progress for: $currentUserId');
        final progressList = await _firestoreRepo.getAllUserDeckProgress(currentUserId);
        debugPrint('📊 Found ${progressList.length} deck progress records');
        
        // Load all flashcard progress to recalculate completion status accurately
        Map<String, int> deckUniqueFlashcardCounts = {};
        Map<String, int> deckKnownFlashcardCounts = {};
        try {
          final flashcardProgressList = await _firestoreRepo.getAllUserFlashcardProgress(currentUserId);
          debugPrint('📊 Found ${flashcardProgressList.length} flashcard progress records');
          
          // Group by deckId and count unique flashcards
          for (var flashcardProgress in flashcardProgressList) {
            final deckId = flashcardProgress['deckId'] as String?;
            if (deckId != null && deckId.isNotEmpty) {
              deckUniqueFlashcardCounts[deckId] = (deckUniqueFlashcardCounts[deckId] ?? 0) + 1;
              
              // Count known flashcards
              if (flashcardProgress['isKnown'] == true) {
                deckKnownFlashcardCounts[deckId] = (deckKnownFlashcardCounts[deckId] ?? 0) + 1;
              }
            }
          }
          debugPrint('📊 Unique flashcard counts by deck: $deckUniqueFlashcardCounts');
          debugPrint('📊 Total decks with flashcard progress: ${deckUniqueFlashcardCounts.length}');
        } catch (e) {
          debugPrint('⚠️ Error loading flashcard progress for completion check: $e');
        }
        
        // Process deck progress records if available
        if (progressList.isNotEmpty) {
          for (var progress in progressList) {
            final deckId = progress['deckId'] as String?;
            if (deckId == null || deckId.isEmpty) {
              debugPrint('⚠️ Found progress record without deckId: ${progress['progressId']}');
              continue;
            }
            
            // Count deck as studied if it has any progress (even if studiedFlashcards is 0)
            studiedDeckIds.add(deckId);
            
            final streak = (progress['currentStreak'] as num?)?.toInt() ?? 0;
            if (streak > maxStreak) {
              maxStreak = streak;
            }
            
            final knownFlashcards = (progress['knownFlashcards'] as num?)?.toInt() ?? 0;
            totalKnownFlashcards += knownFlashcards;
            
            final studiedFlashcards = (progress['studiedFlashcards'] as num?)?.toInt() ?? 0;
            totalStudiedFlashcards += studiedFlashcards;
          }
        }
        
        // Calculate completed decks from flashcard progress (even if no deck progress records)
        // This ensures we count completed decks even if deck progress wasn't created
        Set<String> completedDeckIds = {};
        
        for (var deckId in deckUniqueFlashcardCounts.keys) {
          try {
            // Get total flashcards in deck
            final deckData = await _firestoreRepo.getDeckById(deckId);
            final totalFlashcardsInDeck = (deckData?['flashcardCount'] as num?)?.toInt() ?? 0;
            
            // Get unique flashcards studied for this deck
            final uniqueFlashcardsStudied = deckUniqueFlashcardCounts[deckId] ?? 0;
            
            // Deck is completed when user has studied ALL flashcards
            final isCompleted = totalFlashcardsInDeck > 0 && uniqueFlashcardsStudied >= totalFlashcardsInDeck;
            
            debugPrint('   📝 Deck $deckId:');
            debugPrint('      - Unique flashcards studied: $uniqueFlashcardsStudied');
            debugPrint('      - Total flashcards in deck: $totalFlashcardsInDeck');
            debugPrint('      - Is completed: $isCompleted (${isCompleted ? "✅ YES - User đã học hết tất cả flashcard" : "❌ NO - Còn thiếu ${totalFlashcardsInDeck > uniqueFlashcardsStudied ? totalFlashcardsInDeck - uniqueFlashcardsStudied : 0} flashcard"})');
            
            if (isCompleted) {
              completedDeckIds.add(deckId);
              totalCompletedDecks++;
              debugPrint('      ✅✅✅ COUNTED as completed deck! Total completed now: $totalCompletedDecks');
            }
            
            // Also count as studied deck if user has any flashcard progress
            studiedDeckIds.add(deckId);
            
            // Update known flashcards from flashcard progress
            final knownCount = deckKnownFlashcardCounts[deckId] ?? 0;
            if (knownCount > 0) {
              totalKnownFlashcards += knownCount;
            }
          } catch (e) {
            debugPrint('⚠️ Error processing deck $deckId: $e');
          }
        }
        
        // Update statistics
        _currentStreak = maxStreak;
        _totalKnownFlashcards = totalKnownFlashcards;
        _totalCompletedDecks = totalCompletedDecks;
        _totalDecksStudied = studiedDeckIds.length;
        
        // Use flashcard progress count if available, otherwise use deck progress
        if (deckUniqueFlashcardCounts.isNotEmpty) {
          final totalUniqueFlashcards = deckUniqueFlashcardCounts.values.fold(0, (sum, count) => sum + count);
          _totalFlashcardsStudied = totalUniqueFlashcards;
        } else {
          _totalFlashcardsStudied = totalStudiedFlashcards;
        }
        
        debugPrint('📊 Deck progress stats (FINAL VALUES):');
        debugPrint('   - Decks studied: $_totalDecksStudied (${studiedDeckIds.toList()})');
        debugPrint('   - Current streak: $_currentStreak days');
        debugPrint('   - Known flashcards: $_totalKnownFlashcards');
        debugPrint('   - Studied flashcards: $_totalFlashcardsStudied');
        debugPrint('   - ✅✅✅ Completed decks: $_totalCompletedDecks (calculated: $totalCompletedDecks)');
        debugPrint('   - Completed deck IDs: ${completedDeckIds.toList()}');
        debugPrint('   - ${totalCompletedDecks > 0 ? "✅✅✅ Có $totalCompletedDecks deck đã hoàn thành" : "❌ Chưa có deck nào hoàn thành"}');
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error loading deck progress: $e');
        debugPrint('⚠️ Stack trace: $stackTrace');
        // Reset to 0 on error
        _totalDecksStudied = 0;
        _totalFlashcardsStudied = 0;
      }
      
      // 4a. Also count decks from study sessions if deck progress is empty
      // This ensures we count decks even if progress wasn't saved properly
      if (_totalDecksStudied == 0) {
        try {
          debugPrint('📊 Trying to count decks from study sessions...');
          final studySessions = await _firestoreRepo.getUserStudySessions(currentUserId);
          Set<String> sessionDeckIds = {};
          
          for (var session in studySessions) {
            final deckId = session['deckId'] as String?;
            if (deckId != null && deckId.isNotEmpty) {
              sessionDeckIds.add(deckId);
            }
          }
          
          if (sessionDeckIds.isNotEmpty) {
            debugPrint('📊 Found ${sessionDeckIds.length} decks from study sessions: ${sessionDeckIds.toList()}');
            _totalDecksStudied = sessionDeckIds.length;
          }
        } catch (e) {
          debugPrint('⚠️ Error counting decks from sessions: $e');
        }
      }
      
      // 4b. Also try to get unique flashcard count from user_flashcard_progress
      // This gives us the actual number of unique flashcards studied
      try {
        debugPrint('📊 Loading flashcard progress for: $currentUserId');
        final flashcardProgressList = await _firestoreRepo.getAllUserFlashcardProgress(currentUserId);
        debugPrint('📊 Found ${flashcardProgressList.length} flashcard progress records');
        
        if (flashcardProgressList.isNotEmpty) {
          // Count unique flashcards that have been reviewed at least once
          Set<String> uniqueFlashcardsStudied = {};
          int uniqueKnownFlashcards = 0;
          
          for (var progress in flashcardProgressList) {
            final flashcardId = progress['flashcardId'] as String?;
            if (flashcardId != null) {
              uniqueFlashcardsStudied.add(flashcardId);
              
              final isKnown = progress['isKnown'] == true;
              if (isKnown) {
                uniqueKnownFlashcards++;
              }
            }
          }
          
          // If we have flashcard progress data, use it for more accurate count
          // But keep deck progress count as fallback
          if (uniqueFlashcardsStudied.isNotEmpty) {
            // Use the larger value between deck progress and flashcard progress
            // Deck progress gives total reviews, flashcard progress gives unique count
            if (uniqueFlashcardsStudied.length > _totalFlashcardsStudied) {
              debugPrint('📊 Using flashcard progress count: ${uniqueFlashcardsStudied.length} unique flashcards');
              _totalFlashcardsStudied = uniqueFlashcardsStudied.length;
            }
            
            if (uniqueKnownFlashcards > _totalKnownFlashcards) {
              _totalKnownFlashcards = uniqueKnownFlashcards;
            }
          }
          
          debugPrint('📊 Flashcard progress stats:');
          debugPrint('   - Unique flashcards studied: ${uniqueFlashcardsStudied.length}');
          debugPrint('   - Unique known flashcards: $uniqueKnownFlashcards');
        }
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error loading flashcard progress: $e');
        debugPrint('⚠️ Stack trace: $stackTrace');
        // Don't reset here, keep deck progress values
      }

      // 5. Load study sessions to calculate time-based statistics
      try {
        debugPrint('📊 Loading study sessions for user: $currentUserId');
        final studySessions = await _firestoreRepo.getUserStudySessions(currentUserId);
        debugPrint('📊 Found ${studySessions.length} study sessions');
        
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        final monthStart = DateTime(now.year, now.month, 1);
        
        Set<String> todayDeckIds = {};
        Set<String> weekDeckIds = {};
        Set<String> monthDeckIds = {};
        
        int totalSessions = studySessions.length;
        int totalDuration = 0;
        int validSessions = 0;
        
        for (var session in studySessions) {
          try {
            final startTimeStr = session['startTime'] as String?;
            if (startTimeStr == null || startTimeStr.isEmpty) {
              debugPrint('⚠️ Session ${session['sessionId']} has no startTime');
              continue;
            }
            
            DateTime? startTime;
            try {
              startTime = DateTime.parse(startTimeStr);
            } catch (e) {
              debugPrint('⚠️ Failed to parse startTime "$startTimeStr": $e');
              continue;
            }
            
            final duration = (session['duration'] as num?)?.toInt() ?? 0;
            final flashcardsStudied = (session['flashcardsStudied'] as num?)?.toInt() ?? 0;
            final deckId = session['deckId'] as String?;
            
            validSessions++;
            totalDuration += duration;
            
            // Today
            if (startTime.isAfter(todayStart) || startTime.isAtSameMomentAs(todayStart)) {
              _todayFlashcardsStudied += flashcardsStudied;
              _todayStudyTimeMinutes += duration;
              if (deckId != null) {
                todayDeckIds.add(deckId);
              }
            }
            
            // This week
            if (startTime.isAfter(weekStart) || startTime.isAtSameMomentAs(weekStart)) {
              _weekFlashcardsStudied += flashcardsStudied;
              _weekStudyTimeMinutes += duration;
              if (deckId != null) {
                weekDeckIds.add(deckId);
              }
            }
            
            // This month
            if (startTime.isAfter(monthStart) || startTime.isAtSameMomentAs(monthStart)) {
              _monthFlashcardsStudied += flashcardsStudied;
              _monthStudyTimeMinutes += duration;
              if (deckId != null) {
                monthDeckIds.add(deckId);
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error processing session ${session['sessionId']}: $e');
          }
        }
        
        _todayDecksStudied = todayDeckIds.length;
        _weekDecksStudied = weekDeckIds.length;
        _monthDecksStudied = monthDeckIds.length;
        
        debugPrint('📊 Study sessions processed: $validSessions/$totalSessions valid');
        debugPrint('📊 Today: $_todayFlashcardsStudied flashcards, $_todayStudyTimeMinutes min, $_todayDecksStudied decks');
        debugPrint('📊 Week: $_weekFlashcardsStudied flashcards, $_weekStudyTimeMinutes min, $_weekDecksStudied decks');
        debugPrint('📊 Month: $_monthFlashcardsStudied flashcards, $_monthStudyTimeMinutes min, $_monthDecksStudied decks');
        
        // Calculate average study time per session
        if (validSessions > 0) {
          _averageStudyTimePerSession = totalDuration / validSessions;
        }
        
        // Update total study time from sessions if available
        // Also sum up from deck progress if sessions don't have complete data
        if (totalDuration > 0) {
          _totalStudyTimeMinutes = totalDuration;
        } else {
          // Fallback: try to get from deck progress
          try {
            final progressList = await _firestoreRepo.getAllUserDeckProgress(currentUserId);
            int totalTimeFromProgress = 0;
            for (var progress in progressList) {
              final studyTime = (progress['totalStudyTime'] as num?)?.toInt() ?? 0;
              totalTimeFromProgress += studyTime;
            }
            if (totalTimeFromProgress > 0) {
              _totalStudyTimeMinutes = totalTimeFromProgress;
            }
          } catch (e) {
            debugPrint('⚠️ Error getting study time from progress: $e');
          }
        }
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error loading study sessions: $e');
        debugPrint('⚠️ Stack trace: $stackTrace');
      }

      debugPrint('✅ Statistics loaded (BEFORE setState):');
      debugPrint('   - Total decks created: $_totalDecks');
      debugPrint('   - Total flashcards created: $_totalFlashcards');
      debugPrint('   - Decks studied: $_totalDecksStudied');
      debugPrint('   - Flashcards studied: $_totalFlashcardsStudied');
      debugPrint('   - Known flashcards: $_totalKnownFlashcards');
      debugPrint('   - ✅✅✅ Completed decks: $_totalCompletedDecks (THIS WILL BE DISPLAYED ON UI)');
      
      setState(() {
        _isLoading = false;
        // Explicitly ensure all values are set
        debugPrint('🔄 setState called - UI will rebuild with _totalCompletedDecks = $_totalCompletedDecks');
      });

      debugPrint('✅ Statistics loaded (AFTER setState):');
      debugPrint('   - Completed decks: $_totalCompletedDecks');
      debugPrint('   - Study time: $_totalStudyTimeMinutes minutes');
      debugPrint('   - Current streak: $_currentStreak days');
      debugPrint('   - Favorite decks: $_favoriteDecksCount');
      debugPrint('   - Today: $_todayFlashcardsStudied flashcards, $_todayStudyTimeMinutes min');
      debugPrint('   - Week: $_weekFlashcardsStudied flashcards, $_weekStudyTimeMinutes min');
      debugPrint('   - Month: $_monthFlashcardsStudied flashcards, $_monthStudyTimeMinutes min');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading statistics: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải thống kê: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatStudyTime(int minutes) {
    if (minutes < 60) {
      return '$minutes phút';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours giờ';
      }
      return '$hours giờ $mins phút';
    } else {
      final days = minutes ~/ 1440;
      final hours = (minutes % 1440) ~/ 60;
      if (hours == 0) {
        return '$days ngày';
      }
      return '$days ngày $hours giờ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview section
                    Text(
                      'Tổng quan',
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
                      childAspectRatio: 1.2,
                      children: [
                        _StatCard(
                          icon: Icons.collections_bookmark,
                          label: 'Tổng Deck',
                          value: '$_totalDecks',
                          color: Colors.blue,
                        ),
                        _StatCard(
                          icon: Icons.credit_card,
                          label: 'Tổng Flashcard',
                          value: '$_totalFlashcards',
                          color: Colors.green,
                        ),
                        _StatCard(
                          icon: Icons.favorite,
                          label: 'Deck yêu thích',
                          value: '$_favoriteDecksCount',
                          color: Colors.pink,
                        ),
                        _StatCard(
                          icon: Icons.local_fire_department,
                          label: 'Chuỗi ngày học',
                          value: '$_currentStreak',
                          color: Colors.orange,
                          suffix: ' ngày',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Study statistics section
                    Text(
                      'Thống kê học tập',
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
                      childAspectRatio: 1.2,
                      children: [
                        _StatCard(
                          icon: Icons.school,
                          label: 'Deck đã học',
                          value: '$_totalDecksStudied',
                          color: Colors.purple,
                        ),
                        _StatCard(
                          icon: Icons.quiz,
                          label: 'Flashcard đã học',
                          value: '$_totalFlashcardsStudied',
                          color: Colors.teal,
                        ),
                        _StatCard(
                          icon: Icons.access_time,
                          label: 'Thời gian học',
                          value: _formatStudyTime(_totalStudyTimeMinutes),
                          color: Colors.indigo,
                        ),
                        _StatCard(
                          icon: Icons.trending_up,
                          label: 'Đã học hôm nay',
                          value: '$_todayFlashcardsStudied',
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Time-based statistics
                    Text(
                      'Thống kê theo thời gian',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _TimeStatSection(
                      title: 'Hôm nay',
                      flashcardsStudied: _todayFlashcardsStudied,
                      studyTimeMinutes: _todayStudyTimeMinutes,
                      decksStudied: _todayDecksStudied,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _TimeStatSection(
                      title: 'Tuần này',
                      flashcardsStudied: _weekFlashcardsStudied,
                      studyTimeMinutes: _weekStudyTimeMinutes,
                      decksStudied: _weekDecksStudied,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _TimeStatSection(
                      title: 'Tháng này',
                      flashcardsStudied: _monthFlashcardsStudied,
                      studyTimeMinutes: _monthStudyTimeMinutes,
                      decksStudied: _monthDecksStudied,
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 24),
                    
                    // Additional statistics
                    Text(
                      'Thống kê chi tiết',
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
                      childAspectRatio: 1.2,
                      children: [
                        _StatCard(
                          icon: Icons.check_circle,
                          label: 'Flashcard đã thuộc',
                          value: '$_totalKnownFlashcards',
                          color: Colors.green,
                        ),
                        _StatCard(
                          icon: Icons.flag,
                          label: 'Deck hoàn thành',
                          value: '$_totalCompletedDecks',
                          color: Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Additional info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Thông tin chi tiết',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              label: 'Tổng số deck đã tạo',
                              value: '$_totalDecks',
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              label: 'Tổng số flashcard đã tạo',
                              value: '$_totalFlashcards',
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              label: 'Số deck đã học',
                              value: '$_totalDecksStudied',
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              label: 'Số flashcard đã học',
                              value: '$_totalFlashcardsStudied',
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              label: 'Flashcard đã thuộc',
                              value: '$_totalKnownFlashcards',
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              label: 'Deck đã hoàn thành',
                              value: '$_totalCompletedDecks',
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              label: 'Tổng thời gian học tập',
                              value: _formatStudyTime(_totalStudyTimeMinutes),
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              label: 'Thời gian trung bình/phiên',
                              value: _formatStudyTime(_averageStudyTimePerSession.round()),
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              label: 'Chuỗi ngày học liên tiếp',
                              value: '$_currentStreak ngày',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
  final String? suffix;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.suffix,
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
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                children: [
                  TextSpan(text: value),
                  if (suffix != null)
                    TextSpan(
                      text: suffix,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: color.withValues(alpha: 0.7),
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeStatSection extends StatelessWidget {
  final String title;
  final int flashcardsStudied;
  final int studyTimeMinutes;
  final int decksStudied;
  final Color color;

  const _TimeStatSection({
    required this.title,
    required this.flashcardsStudied,
    required this.studyTimeMinutes,
    required this.decksStudied,
    required this.color,
  });

  String _formatStudyTime(int minutes) {
    if (minutes < 60) {
      return '$minutes phút';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours giờ';
      }
      return '$hours giờ $mins phút';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStatItem(
                    icon: Icons.quiz,
                    label: 'Flashcard',
                    value: '$flashcardsStudied',
                    color: color,
                  ),
                ),
                Expanded(
                  child: _MiniStatItem(
                    icon: Icons.access_time,
                    label: 'Thời gian',
                    value: _formatStudyTime(studyTimeMinutes),
                    color: color,
                  ),
                ),
                Expanded(
                  child: _MiniStatItem(
                    icon: Icons.collections_bookmark,
                    label: 'Deck',
                    value: '$decksStudied',
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }
}

