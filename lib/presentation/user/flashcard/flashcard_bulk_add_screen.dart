import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../../data/services/flashcard_parser_service.dart';
import '../../../data/services/file_import_service.dart';
import '../../../core/services/auth_service.dart';

class FlashcardBulkAddScreen extends StatefulWidget {
  final String deckId;
  
  const FlashcardBulkAddScreen({
    super.key,
    required this.deckId,
  });

  @override
  State<FlashcardBulkAddScreen> createState() => _FlashcardBulkAddScreenState();
}

class _FlashcardBulkAddScreenState extends State<FlashcardBulkAddScreen> {
  final _textController = TextEditingController();
  final _firestoreRepo = FirestoreRepository();
  List<Map<String, String>> _parsedFlashcards = [];
  List<String> _validationErrors = [];
  bool _isLoading = false;
  bool _showPreview = false;
  String? _importedFileName;

  @override
  void initState() {
    super.initState();
    // Set example text
    _textController.text = FlashcardParserService.getExampleText();
    _parseInput();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseInput() {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _parsedFlashcards = [];
        _validationErrors = [];
      });
      return;
    }
    
    _parsedFlashcards = FlashcardParserService.parseTextInput(text);
    _validationErrors = FlashcardParserService.validateFlashcards(_parsedFlashcards);
    
    setState(() {});
  }

  Future<void> _saveFlashcards() async {
    if (_parsedFlashcards.isEmpty || _validationErrors.isNotEmpty) {
      return;
    }

    // Check authentication
    final userId = AuthService.currentUserId;
    if (userId == null) {
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

    setState(() => _isLoading = true);

    try {
      // Convert to Firestore format
      final flashcardsData = _parsedFlashcards.map((card) => {
        'front': card['front'] ?? '',
        'back': card['back'] ?? '',
        'tags': <String>[],
      }).toList();

      debugPrint('🔄 Starting batch create: ${flashcardsData.length} flashcards');
      
      await _firestoreRepo.batchCreateFlashcards(
        deckId: widget.deckId,
        flashcardsData: flashcardsData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã tạo thành công ${_parsedFlashcards.length} flashcard'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving flashcards: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        String errorMessage = 'Lỗi: ${e.toString()}';
        if (e.toString().contains('permission') || e.toString().contains('Permission')) {
          errorMessage = 'Bạn không có quyền thực hiện thao tác này';
        } else if (e.toString().contains('network') || e.toString().contains('Network')) {
          errorMessage = 'Lỗi kết nối mạng. Vui lòng kiểm tra internet và thử lại';
        } else if (e.toString().contains('Deck not found')) {
          errorMessage = 'Không tìm thấy deck. Vui lòng thử lại.';
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

  Future<void> _importFromFile() async {
    try {
      // Pick file (chỉ cho phép TXT)
      final fileData = await FileImportService.pickFile(
        allowedExtensions: ['txt'],
      );

      if (fileData == null) {
        // User cancelled
        return;
      }

      final filePath = fileData['path'] as String?;
      final fileBytes = fileData['bytes'] as List<int>?;
      final fileName = fileData['name'] as String? ?? 'unknown';

      debugPrint('📁 File picked:');
      debugPrint('  - Name: $fileName');
      debugPrint('  - Path: $filePath');
      debugPrint('  - Has bytes: ${fileBytes != null && fileBytes.isNotEmpty}');
      debugPrint('  - Bytes length: ${fileBytes?.length ?? 0}');

      // Kiểm tra có dữ liệu không
      if (filePath == null && (fileBytes == null || fileBytes.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể đọc file. Vui lòng thử lại hoặc download file về máy trước.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      setState(() => _isLoading = true);

      // Import file TXT (hỗ trợ cả path và bytes)
      final result = await FileImportService.importFromFile(
        filePath: filePath,
        bytes: fileBytes,
        fileName: fileName,
      );
      
      final flashcards = result['flashcards'] as List<Map<String, String>>;
      final fileType = result['fileType'] as String;
      final importedFileName = result['fileName'] as String? ?? fileName;

      debugPrint('✅ Imported ${flashcards.length} flashcards');

      // Update UI
      setState(() {
        _parsedFlashcards = flashcards;
        _importedFileName = importedFileName;
        _validationErrors = FlashcardParserService.validateFlashcards(flashcards);
        // Update text controller để hiển thị
        _textController.text = flashcards.map((card) {
          return '${card['front']} | ${card['back']}';
        }).join('\n');
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã import ${flashcards.length} flashcard từ file $fileType'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error importing file: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        String errorMessage = 'Lỗi import file: ${e.toString()}';
        
        // Customize error messages
        if (e.toString().contains('Không tìm thấy flashcard')) {
          errorMessage = 'Không tìm thấy flashcard nào trong file.\n\n'
              'Vui lòng kiểm tra:\n'
              '• Định dạng file đúng (TXT: front | back hoặc front - back)\n'
              '• File không trống\n'
              '• Encoding là UTF-8';
        } else if (e.toString().contains('Không thể đọc file')) {
          errorMessage = 'Không thể đọc file.\n\n'
              'Vui lòng:\n'
              '• Download file từ Google Drive về máy trước\n'
              '• Hoặc chọn file từ thư mục local';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm Flashcard Hàng Loạt'),
        actions: [
          if (_parsedFlashcards.isNotEmpty)
            IconButton(
              icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() {
                  _showPreview = !_showPreview;
                });
              },
              tooltip: _showPreview ? 'Ẩn preview' : 'Xem preview',
            ),
        ],
      ),
      body: Column(
        children: [
          // Info card
          Card(
            margin: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hướng dẫn',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nhập flashcard theo định dạng:\n'
                    '• apple | táo\n'
                    '• banana - chuối\n'
                    '• cat : con mèo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _importFromFile,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Import File TXT'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_importedFileName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.file_present,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'File: $_importedFileName',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Input area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nhập flashcard',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_parsedFlashcards.isNotEmpty)
                        Chip(
                          label: Text('${_parsedFlashcards.length} flashcard'),
                          avatar: const Icon(Icons.check_circle, size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'apple | táo\nbanana - chuối\ncat : con mèo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      onChanged: (_) => _parseInput(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Validation errors
                  if (_validationErrors.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Lỗi:',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ..._validationErrors.take(5).map((error) => Padding(
                                padding: const EdgeInsets.only(left: 28, top: 4),
                                child: Text(
                                  '• $error',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              )),
                          if (_validationErrors.length > 5)
                            Padding(
                              padding: const EdgeInsets.only(left: 28, top: 4),
                              child: Text(
                                '... và ${_validationErrors.length - 5} lỗi khác',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Preview area
          if (_showPreview && _parsedFlashcards.isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.preview, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Preview (${_parsedFlashcards.length} flashcard)',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _parsedFlashcards.length,
                      itemBuilder: (context, index) {
                        final card = _parsedFlashcards[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              card['front'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(card['back'] ?? ''),
                            dense: true,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.05 * 255).round()),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: (_parsedFlashcards.isEmpty || 
                                _validationErrors.isNotEmpty || 
                                _isLoading)
                        ? null
                        : _saveFlashcards,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isLoading
                          ? 'Đang lưu...'
                          : 'Lưu (${_parsedFlashcards.length})',
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

