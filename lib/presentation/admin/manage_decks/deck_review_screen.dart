import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_repository.dart';

class DeckReviewScreen extends StatefulWidget {
  final String deckId;
  
  const DeckReviewScreen({
    super.key,
    required this.deckId,
  });

  @override
  State<DeckReviewScreen> createState() => _DeckReviewScreenState();
}

class _DeckReviewScreenState extends State<DeckReviewScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  Map<String, dynamic>? _deck;
  List<Map<String, dynamic>> _flashcards = [];
  bool _isLoading = true;

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
      final deck = await _firestoreRepo.getDeckById(widget.deckId);
      final flashcards = await _firestoreRepo.getFlashcardsByDeck(widget.deckId);
      setState(() {
        _deck = deck;
        _flashcards = flashcards;
        _isLoading = false;
      });
      debugPrint('✅ Loaded deck: ${deck?['name']}');
      debugPrint('✅ Loaded ${flashcards.length} flashcards');
    } catch (e) {
      debugPrint('❌ Error loading deck data: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải deck: $e'),
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
        appBar: AppBar(title: const Text('Duyệt Deck')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_deck == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duyệt Deck')),
        body: const Center(child: Text('Không tìm thấy deck')),
      );
    }

    final status = _deck?['status'] ?? _deck?['approvalStatus'] ?? 'reported';
    final isHidden = status == 'hidden';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Deck'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deck info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
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
                                _deck!['name'] ?? 'Unknown',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tác giả: ${_deck!['authorName'] ?? 'Unknown'}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            status == 'reported' ? 'Bị báo cáo' :
                            status == 'hidden' ? 'Đã ẩn' : 'Khác',
                          ),
                          backgroundColor: status == 'reported' ? Colors.orange[100] :
                              status == 'hidden' ? Colors.red[100] : Colors.grey[100],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mô tả:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _deck!['description'] ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _InfoItem(
                          icon: Icons.credit_card,
                          label: 'Flashcard',
                          value: '${_deck!['flashcardCount'] ?? 0}',
                        ),
                        _InfoItem(
                          icon: Icons.visibility,
                          label: 'Lượt xem',
                          value: '${_deck!['viewCount'] ?? 0}',
                        ),
                        _InfoItem(
                          icon: Icons.favorite,
                          label: 'Yêu thích',
                          value: '${_deck!['favoriteCount'] ?? 0}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Actions (Post-moderation: hide/restore)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thao tác',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (isHidden)
                      FilledButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text('Khôi phục deck'),
                        onPressed: _showRestoreDialog,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.visibility_off),
                        label: const Text('Ẩn deck'),
                        onPressed: _showHideDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Flashcard preview
            Text(
              'Xem trước Flashcard (${_flashcards.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _flashcards.isEmpty
                ? _EmptyFlashcardPreview()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _flashcards.length,
                    itemBuilder: (context, index) {
                      final flashcard = _flashcards[index];
                      final front = flashcard['front'] as String? ?? '';
                      final back = flashcard['back'] as String? ?? '';
                      final tags = (flashcard['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              front.isNotEmpty ? front[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(front),
                          subtitle: const Text('Nhấn để xem đáp án'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mặt sau: $back',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  if (tags.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: tags.map((tag) {
                                        return Chip(
                                          label: Text(tag),
                                          labelStyle: const TextStyle(fontSize: 12),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _showHideDialog() {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ẩn deck'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Deck này sẽ bị ẩn khỏi danh sách công khai. Nhập lý do:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Lý do ẩn deck...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
                    content: Text('Vui lòng nhập lý do ẩn deck'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                await _firestoreRepo.hideDeck(widget.deckId, reasonController.text.trim());
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadDeckData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deck đã bị ẩn'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
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
            child: const Text('Ẩn deck'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục deck'),
        content: const Text('Deck này sẽ được hiển thị lại trong danh sách công khai. Bạn có chắc chắn?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _firestoreRepo.restoreDeck(widget.deckId);
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadDeckData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deck đã được khôi phục'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
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
            child: const Text('Khôi phục'),
          ),
        ],
      ),
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

class _EmptyFlashcardPreview extends StatelessWidget {
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
          ],
        ),
      ),
    );
  }
}
