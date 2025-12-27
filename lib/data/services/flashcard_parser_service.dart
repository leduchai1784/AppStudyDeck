import 'package:flutter/foundation.dart';

/// Service để parse text input thành flashcard pairs
class FlashcardParserService {
  /// Parse text input thành list flashcard pairs
  /// Hỗ trợ các delimiter: |, -, :
  /// 
  /// Ví dụ:
  /// - "apple | táo"
  /// - "banana - chuối"
  /// - "cat : con mèo"
  static List<Map<String, String>> parseTextInput(String text) {
    final lines = text.split('\n');
    final flashcards = <Map<String, String>>[];
    
    debugPrint('📝 Parsing ${lines.length} lines...');
    
    for (int i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) {
        debugPrint('  Line ${i + 1}: Empty, skipping');
        continue;
      }
      
      debugPrint('  Line ${i + 1}: "$line"');
      
      String? front, back;
      
      // Thử các delimiter theo thứ tự: |, -, :, comma, tab
      if (line.contains('|')) {
        // Split by | (pipe)
        final parts = line.split('|');
        debugPrint('    Split by |: ${parts.length} parts');
        if (parts.length >= 2) {
          front = parts[0].trim();
          // Join lại các phần sau dấu | để tránh lỗi nếu có nhiều dấu |
          back = parts.sublist(1).join('|').trim();
          debugPrint('    → Front: "$front", Back: "$back"');
        }
      } else if (line.contains('-')) {
        // Kiểm tra không phải dấu trừ trong số âm
        // Pattern: text - text (có khoảng trắng xung quanh dấu -)
        final regex = RegExp(r'^(.+?)\s*-\s*(.+)$');
        final match = regex.firstMatch(line);
        if (match != null) {
          front = match.group(1)?.trim();
          back = match.group(2)?.trim();
          debugPrint('    Split by -: Front: "$front", Back: "$back"');
        } else {
          debugPrint('    - found but regex not matched');
        }
      } else if (line.contains(':')) {
        // Split by : (colon)
        final parts = line.split(':');
        debugPrint('    Split by :: ${parts.length} parts');
        if (parts.length >= 2) {
          front = parts[0].trim();
          // Join lại các phần sau dấu : để tránh lỗi nếu có nhiều dấu :
          back = parts.sublist(1).join(':').trim();
          debugPrint('    → Front: "$front", Back: "$back"');
        }
      } else if (line.contains(',')) {
        // Thử comma như CSV
        final parts = line.split(',');
        debugPrint('    Split by comma: ${parts.length} parts');
        if (parts.length >= 2) {
          front = parts[0].trim();
          back = parts.sublist(1).join(',').trim();
          debugPrint('    → Front: "$front", Back: "$back"');
        }
      } else if (line.contains('\t')) {
        // Thử tab
        final parts = line.split('\t');
        debugPrint('    Split by tab: ${parts.length} parts');
        if (parts.length >= 2) {
          front = parts[0].trim();
          back = parts.sublist(1).join('\t').trim();
          debugPrint('    → Front: "$front", Back: "$back"');
        }
      } else {
        debugPrint('    ⚠️ No delimiter found (|, -, :, comma, tab)');
      }
      
      // Validate và thêm vào list
      if (front != null && back != null && front.isNotEmpty && back.isNotEmpty) {
        flashcards.add({
          'front': front,
          'back': back,
          'lineNumber': (i + 1).toString(), // Lưu số dòng để hiển thị lỗi
        });
        debugPrint('    ✅ Added flashcard');
      } else {
        debugPrint('    ⚠️ Warning: Không thể parse dòng ${i + 1}: "$line"');
        debugPrint('    Front: ${front ?? "null"}, Back: ${back ?? "null"}');
      }
    }
    
    debugPrint('📊 Total parsed: ${flashcards.length} flashcards');
    return flashcards;
  }
  
  /// Validate flashcards trước khi import
  /// Return list các lỗi (nếu có)
  static List<String> validateFlashcards(List<Map<String, String>> flashcards) {
    final errors = <String>[];
    
    if (flashcards.isEmpty) {
      errors.add('Không có flashcard nào được tìm thấy');
      return errors;
    }
    
    for (int i = 0; i < flashcards.length; i++) {
      final card = flashcards[i];
      final lineNumber = card['lineNumber'] ?? (i + 1).toString();
      
      if (card['front']?.isEmpty ?? true) {
        errors.add('Dòng $lineNumber: Thiếu mặt trước');
      }
      if (card['back']?.isEmpty ?? true) {
        errors.add('Dòng $lineNumber: Thiếu mặt sau');
      }
      
      // Kiểm tra độ dài (optional - có thể bỏ qua)
      if ((card['front']?.length ?? 0) > 1000) {
        errors.add('Dòng $lineNumber: Mặt trước quá dài (tối đa 1000 ký tự)');
      }
      if ((card['back']?.length ?? 0) > 1000) {
        errors.add('Dòng $lineNumber: Mặt sau quá dài (tối đa 1000 ký tự)');
      }
    }
    
    return errors;
  }
  
  /// Parse từ CSV content
  /// Format: front,back hoặc front|back
  static List<Map<String, String>> parseCSVContent(String csvContent) {
    final flashcards = <Map<String, String>>[];
    final lines = csvContent.split('\n');
    
    // Skip header nếu có
    int startIndex = 0;
    if (lines.isNotEmpty && 
        (lines[0].toLowerCase().contains('front') || 
         lines[0].toLowerCase().contains('back'))) {
      startIndex = 1;
    }
    
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      // CSV có thể dùng comma hoặc pipe
      List<String> parts;
      if (line.contains(',')) {
        parts = line.split(',');
      } else if (line.contains('|')) {
        parts = line.split('|');
      } else {
        continue;
      }
      
      if (parts.length >= 2) {
        final front = parts[0].trim();
        final back = parts.sublist(1).join(',').trim(); // Join lại nếu có comma trong nội dung
        
        if (front.isNotEmpty && back.isNotEmpty) {
          flashcards.add({
            'front': front,
            'back': back,
            'lineNumber': (i + 1).toString(),
          });
        }
      }
    }
    
    return flashcards;
  }
  
  /// Get example text để hiển thị trong UI
  static String getExampleText() {
    return '''apple | táo
banana - chuối
cat : con mèo
dog | con chó
elephant - con voi''';
  }
}

