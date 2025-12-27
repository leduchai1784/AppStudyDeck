import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../../data/models/flashcard_model.dart';
import '../../../core/services/auth_service.dart';

class FlashcardEditScreen extends StatefulWidget {
  final String? deckId;
  final String? flashcardId;
  
  const FlashcardEditScreen({
    super.key,
    this.deckId,
    this.flashcardId,
  });

  @override
  State<FlashcardEditScreen> createState() => _FlashcardEditScreenState();
}

class _FlashcardEditScreenState extends State<FlashcardEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  final _tagsController = TextEditingController();
  final _firestoreRepo = FirestoreRepository();
  bool _isLoading = false;
  FlashcardModel? _existingFlashcard;

  @override
  void initState() {
    super.initState();
    if (widget.flashcardId != null) {
      _loadFlashcard();
    }
  }

  Future<void> _loadFlashcard() async {
    if (widget.flashcardId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final flashcardData = await _firestoreRepo.getFlashcardById(widget.flashcardId!);
      if (flashcardData != null) {
        // Convert Firestore data to FlashcardModel
        final flashcard = FlashcardModel(
          id: flashcardData['flashcardId'] ?? flashcardData['id'] ?? '',
          deckId: flashcardData['deckId'] ?? '',
          front: flashcardData['front'] ?? '',
          back: flashcardData['back'] ?? '',
          tags: List<String>.from(flashcardData['tags'] ?? []),
          createdAt: flashcardData['createdAt'] != null
              ? DateTime.parse(flashcardData['createdAt'])
              : DateTime.now(),
          updatedAt: flashcardData['updatedAt'] != null
              ? DateTime.parse(flashcardData['updatedAt'])
              : DateTime.now(),
          reviewCount: flashcardData['reviewCount'] ?? 0,
          isKnown: flashcardData['isKnown'] ?? false,
        );
        
        setState(() {
          _existingFlashcard = flashcard;
          _frontController.text = flashcard.front;
          _backController.text = flashcard.back;
          _tagsController.text = flashcard.tags.join(', ');
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy flashcard'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading flashcard: $e');
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

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || widget.deckId == null) {
      return;
    }

    // Check if user is authenticated
    final currentUserId = AuthService.currentUserId;
    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để thực hiện thao tác này'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      if (widget.flashcardId != null) {
        // Update existing flashcard
        await _firestoreRepo.updateFlashcard(
          widget.flashcardId!,
          {
            'front': _frontController.text.trim(),
            'back': _backController.text.trim(),
            'tags': tags,
          },
        );
        
        debugPrint('✅ Flashcard updated successfully');
      } else {
        // Create new flashcard
        // Order will be auto-calculated in createFlashcard method
        debugPrint('🔄 Creating new flashcard for deck: ${widget.deckId}');
        debugPrint('📝 Front: ${_frontController.text.trim()}');
        debugPrint('📝 Back: ${_backController.text.trim()}');
        debugPrint('🏷️ Tags: $tags');
        
        final flashcardId = await _firestoreRepo.createFlashcard({
          'deckId': widget.deckId!,
          'front': _frontController.text.trim(),
          'back': _backController.text.trim(),
          'tags': tags,
        });
        
        debugPrint('✅ Flashcard created successfully with ID: $flashcardId');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.flashcardId != null
                ? 'Đã cập nhật flashcard'
                : 'Đã tạo flashcard mới'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving flashcard: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        String errorMessage = 'Lỗi: ${e.toString()}';
        
        // Parse error message for better user experience
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('permission') || errorStr.contains('denied')) {
          errorMessage = 'Bạn không có quyền thực hiện thao tác này.\nChỉ có thể thêm flashcard vào deck của chính bạn.';
        } else if (errorStr.contains('network') || errorStr.contains('connection')) {
          errorMessage = 'Lỗi kết nối mạng.\nVui lòng kiểm tra internet và thử lại.';
        } else if (errorStr.contains('deck not found')) {
          errorMessage = 'Không tìm thấy deck.\nVui lòng thử lại sau.';
        } else if (errorStr.contains('must be authenticated')) {
          errorMessage = 'Vui lòng đăng nhập để thực hiện thao tác này.';
        } else if (errorStr.contains('your own decks')) {
          errorMessage = 'Bạn chỉ có thể thêm flashcard vào deck của chính mình.';
        } else if (errorStr.contains('index')) {
          errorMessage = 'Lỗi truy vấn dữ liệu.\nVui lòng liên hệ quản trị viên.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.flashcardId != null;
    
    if (_isLoading && _existingFlashcard == null && isEdit) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Chỉnh sửa Flashcard' : 'Tạo Flashcard mới'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Chỉnh sửa Flashcard' : 'Tạo Flashcard mới'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Front side
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mặt trước',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _frontController,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: 'Nhập nội dung mặt trước...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập nội dung mặt trước';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Back side
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_off,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mặt sau',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _backController,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: 'Nhập nội dung mặt sau...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập nội dung mặt sau';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Tags
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.label_outline,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tags',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tagsController,
                        decoration: InputDecoration(
                          hintText: 'Nhập tags cách nhau bởi dấu phẩy',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.tag),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Save button
              FilledButton(
                onPressed: _handleSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEdit ? 'Cập nhật' : 'Tạo mới'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

