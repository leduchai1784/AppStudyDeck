import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'flashcard_parser_service.dart';

/// Service để import flashcards từ file (CSV, TXT)
class FileImportService {
  /// Pick file và return file path hoặc bytes
  /// [allowedExtensions] - List các extension được phép (ví dụ: ['csv', 'txt'])
  /// Returns Map với 'path' hoặc 'bytes' và 'name'
  static Future<Map<String, dynamic>?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? ['csv', 'txt'],
        allowMultiple: false,
        withData: true, // Lấy cả bytes để hỗ trợ Google Drive
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.single;
      
      // Trả về cả path và bytes để xử lý cả 2 trường hợp
      return {
        'path': file.path,
        'bytes': file.bytes,
        'name': file.name,
        'size': file.size,
      };
    } catch (e) {
      debugPrint('❌ Error picking file: $e');
      return null;
    }
  }

  /// Read file content as String
  /// Hỗ trợ cả file path và bytes (cho Google Drive)
  static Future<String?> readFileContent(String? filePath, {List<int>? bytes}) async {
    try {
      // Ưu tiên đọc từ bytes nếu có (file từ Google Drive)
      if (bytes != null && bytes.isNotEmpty) {
        debugPrint('📦 Reading from bytes: ${bytes.length} bytes');
        debugPrint('📦 First 50 bytes: ${bytes.take(50).toList()}');
        
        // Decode bytes thành UTF-8 string
        try {
          // Thử UTF-8 decode trước (phổ biến nhất)
          final content = utf8.decode(bytes, allowMalformed: true);
          debugPrint('✅ UTF-8 decode successful: ${content.length} characters');
          debugPrint('📄 First 100 chars: ${content.substring(0, content.length > 100 ? 100 : content.length)}');
          return content;
        } catch (e) {
          debugPrint('⚠️ UTF-8 decode failed: $e');
          debugPrint('⚠️ Trying latin1...');
          
          // Thử latin1 nếu UTF-8 fail
          try {
            final content = latin1.decode(bytes);
            debugPrint('✅ Latin1 decode successful: ${content.length} characters');
            return content;
          } catch (e2) {
            debugPrint('⚠️ Latin1 decode also failed: $e2');
            debugPrint('⚠️ Trying String.fromCharCodes...');
            
            // Fallback: dùng String.fromCharCodes
            try {
              final content = String.fromCharCodes(bytes);
              debugPrint('✅ String.fromCharCodes successful: ${content.length} characters');
              return content;
            } catch (e3) {
              debugPrint('❌ All decode methods failed: $e3');
              return null;
            }
          }
        }
      }
      
      // Đọc từ file path nếu có
      if (filePath != null && filePath.isNotEmpty) {
        debugPrint('📄 Trying to read from file path: $filePath');
        final file = File(filePath);
        if (await file.exists()) {
          debugPrint('✅ File exists, reading...');
          final fileSize = await file.length();
          debugPrint('📄 File size: $fileSize bytes');
          
          // Thử UTF-8 trước
          try {
            final content = await file.readAsString(encoding: utf8);
            debugPrint('✅ Read as UTF-8: ${content.length} characters');
            return content;
          } catch (e) {
            debugPrint('⚠️ UTF-8 read failed: $e, trying default encoding...');
            // Fallback về default encoding
            try {
              final content = await file.readAsString();
              debugPrint('✅ Read with default encoding: ${content.length} characters');
              return content;
            } catch (e2) {
              debugPrint('❌ Default encoding also failed: $e2');
              return null;
            }
          }
        } else {
          debugPrint('⚠️ File does not exist: $filePath');
        }
      }
      
      debugPrint('❌ No bytes and no valid file path');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Error reading file: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  /// Import từ CSV file
  /// Format: front,back hoặc front|back
  /// Có thể có header: front,back
  static Future<List<Map<String, String>>> importFromCSV(String? filePath, {List<int>? bytes}) async {
    try {
      var content = await readFileContent(filePath, bytes: bytes);
      if (content == null || content.isEmpty) {
        throw Exception('Không thể đọc file hoặc file trống');
      }

      debugPrint('📄 Reading CSV file: $filePath');
      debugPrint('📄 Content length: ${content.length} characters');
      debugPrint('📄 Content preview (first 500 chars):');
      debugPrint(content.substring(0, content.length > 500 ? 500 : content.length));
      debugPrint('📄 Content preview (last 200 chars):');
      debugPrint(content.substring(content.length > 200 ? content.length - 200 : 0));
      
      // Kiểm tra BOM (Byte Order Mark) - có thể gây lỗi parse
      if (content.startsWith('\ufeff')) {
        debugPrint('⚠️ Found UTF-8 BOM, removing...');
        content = content.substring(1);
      }
      
      // Normalize line endings
      content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      
      final flashcards = <Map<String, String>>[];
      
      // Thử parse bằng CSV package trước
      try {
        debugPrint('🔄 Trying CSV package parsing...');
        
        // Thử với các delimiter khác nhau
        List<List<dynamic>> csvData;
        String delimiterUsed = ',';
        
        try {
          // Thử comma delimiter trước (phổ biến nhất)
          csvData = const CsvToListConverter(
            fieldDelimiter: ',',
            eol: '\n',
          ).convert(content);
          delimiterUsed = ',';
          debugPrint('✅ CSV package parsed with comma delimiter: ${csvData.length} rows');
        } catch (e1) {
          debugPrint('⚠️ Comma delimiter failed: $e1');
          try {
            // Thử semicolon
            csvData = const CsvToListConverter(
              fieldDelimiter: ';',
              eol: '\n',
            ).convert(content);
            delimiterUsed = ';';
            debugPrint('✅ CSV package parsed with semicolon delimiter: ${csvData.length} rows');
          } catch (e2) {
            debugPrint('⚠️ Semicolon delimiter also failed: $e2');
            // Thử pipe
            csvData = const CsvToListConverter(
              fieldDelimiter: '|',
              eol: '\n',
            ).convert(content);
            delimiterUsed = '|';
            debugPrint('✅ CSV package parsed with pipe delimiter: ${csvData.length} rows');
          }
        }
        
        if (csvData.isEmpty) {
          throw Exception('File CSV trống sau khi parse');
        }

        debugPrint('📊 CSV package parsed ${csvData.length} rows using "$delimiterUsed" delimiter');
        
        // Debug: In ra vài dòng đầu để kiểm tra
        for (int i = 0; i < csvData.length && i < 5; i++) {
          debugPrint('  Row ${i + 1}: $csvData[i]');
        }

        // Check if first row is header (cải thiện detection)
        int startIndex = 0;
        if (csvData.isNotEmpty) {
          final firstRow = csvData[0];
          if (firstRow.isNotEmpty && firstRow.length >= 2) {
            final firstCell = firstRow[0].toString().toLowerCase().trim();
            final secondCell = firstRow.length > 1 ? firstRow[1].toString().toLowerCase().trim() : '';
            
            debugPrint('📋 First row cells: "$firstCell", "$secondCell"');
            
            // Kiểm tra nhiều pattern header
            if (firstCell == 'front' || firstCell == 'từ' || firstCell == 'word' ||
                secondCell == 'back' || secondCell == 'nghĩa' || secondCell == 'meaning' ||
                (firstCell.contains('front') && secondCell.contains('back')) ||
                (firstCell.contains('từ') && secondCell.contains('nghĩa'))) {
              startIndex = 1; // Skip header
              debugPrint('📋 Found header row: [$firstCell, $secondCell], skipping...');
            }
          }
        }

        // Process each row
        int parsedCount = 0;
        int skippedCount = 0;
        for (int i = startIndex; i < csvData.length; i++) {
          final row = csvData[i];
          if (row.isEmpty) {
            skippedCount++;
            continue;
          }
          
          if (row.length < 2) {
            debugPrint('⚠️ Row ${i + 1}: Only ${row.length} column(s), skipping');
            debugPrint('   Row data: $row');
            skippedCount++;
            continue;
          }

          final front = row[0].toString().trim();
          // Nếu có nhiều hơn 2 cột, join các cột sau thành back
          final back = row.length > 2 
              ? row.sublist(1).map((e) => e.toString().trim()).join(' ').trim()
              : row[1].toString().trim();

          debugPrint('📝 Row ${i + 1}: Front="$front", Back="$back"');

          if (front.isEmpty || back.isEmpty) {
            debugPrint('⚠️ Row ${i + 1}: Empty front or back, skipping');
            skippedCount++;
            continue;
          }

          flashcards.add({
            'front': front,
            'back': back,
            'lineNumber': (i + 1).toString(),
          });
          parsedCount++;
        }
        
        debugPrint('✅ CSV package: Parsed $parsedCount, Skipped $skippedCount');
        
        // Nếu parse được ít nhất 1 flashcard, return
        if (flashcards.isNotEmpty) {
          debugPrint('✅ Parsed ${flashcards.length} flashcards from CSV (using CSV package with "$delimiterUsed" delimiter)');
          return flashcards;
        } else {
          throw Exception('Không parse được flashcard nào từ CSV package');
        }
      } catch (csvError) {
        debugPrint('⚠️ CSV package parsing failed: $csvError');
        debugPrint('⚠️ Error type: ${csvError.runtimeType}');
        debugPrint('⚠️ Trying manual parsing as fallback...');
      }
      
      // Fallback: Parse manually (cho trường hợp CSV package fail hoặc format đặc biệt)
      debugPrint('🔄 Trying manual CSV parsing...');
      final lines = content.split('\n');
      debugPrint('📄 Total lines: ${lines.length}');
      
      // Debug: In ra tất cả các dòng để kiểm tra
      for (int i = 0; i < lines.length && i < 10; i++) {
        debugPrint('  Line ${i + 1}: "${lines[i]}" (length: ${lines[i].length})');
      }
      
      int startIndex = 0;
      // Check header - cải thiện detection
      if (lines.isNotEmpty) {
        final firstLine = lines[0].trim();
        final firstLineLower = firstLine.toLowerCase();
        debugPrint('📋 Checking first line for header: "$firstLine"');
        
        // Kiểm tra nhiều pattern header
        if (firstLineLower == 'front,back' || 
            firstLineLower == 'front|back' ||
            firstLineLower.contains('front') && firstLineLower.contains('back') ||
            firstLineLower.contains('từ') && firstLineLower.contains('nghĩa') ||
            firstLineLower.startsWith('front') ||
            firstLineLower.startsWith('từ')) {
          startIndex = 1;
          debugPrint('📋 Found header in first line, skipping...');
        }
      }
      
      int parsedCount = 0;
      int skippedCount = 0;
      for (int i = startIndex; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.isEmpty) {
          skippedCount++;
          continue;
        }
        
        debugPrint('📝 Line ${i + 1}: "$line"');
        
        // Thử các delimiter: comma, pipe, tab, semicolon
        List<String> parts;
        String delimiter = 'unknown';
        
        if (line.contains(',')) {
          // CSV thường dùng comma, nhưng cần xử lý quoted values
          // Tạm thời split đơn giản, có thể cải thiện sau
          parts = line.split(',');
          delimiter = 'comma';
          debugPrint('   Split by comma: ${parts.length} parts');
        } else if (line.contains('|')) {
          parts = line.split('|');
          delimiter = 'pipe';
          debugPrint('   Split by pipe: ${parts.length} parts');
        } else if (line.contains('\t')) {
          parts = line.split('\t');
          delimiter = 'tab';
          debugPrint('   Split by tab: ${parts.length} parts');
        } else if (line.contains(';')) {
          parts = line.split(';');
          delimiter = 'semicolon';
          debugPrint('   Split by semicolon: ${parts.length} parts');
        } else {
          debugPrint('   ⚠️ No delimiter found (tried: comma, pipe, tab, semicolon)');
          skippedCount++;
          continue;
        }
        
        if (parts.length < 2) {
          debugPrint('   ⚠️ Only ${parts.length} part(s), skipping');
          debugPrint('   Parts: $parts');
          skippedCount++;
          continue;
        }
        
        final front = parts[0].trim();
        // Join lại các phần sau để xử lý delimiter trong nội dung
        final back = delimiter == 'comma' 
            ? parts.sublist(1).join(',').trim()
            : parts.sublist(1).join('|').trim();
        
        debugPrint('   Front: "$front" (length: ${front.length})');
        debugPrint('   Back: "$back" (length: ${back.length})');
        
        if (front.isEmpty || back.isEmpty) {
          debugPrint('   ⚠️ Empty front or back, skipping');
          skippedCount++;
          continue;
        }
        
        flashcards.add({
          'front': front,
          'back': back,
          'lineNumber': (i + 1).toString(),
        });
        parsedCount++;
        debugPrint('   ✅ Added flashcard #$parsedCount');
      }
      
      debugPrint('✅ Manual parsing: Parsed $parsedCount, Skipped $skippedCount');
      
      if (flashcards.isEmpty) {
        throw Exception('Không tìm thấy flashcard nào trong file CSV.\n\n'
            'Vui lòng kiểm tra:\n'
            '• Format: front,back (dùng dấu phẩy)\n'
            '• Hoặc: front|back (dùng dấu |)\n'
            '• Mỗi dòng một cặp flashcard\n'
            '• File không trống');
      }
      
      debugPrint('✅ Parsed ${flashcards.length} flashcards from CSV (using manual parsing)');
      return flashcards;
    } catch (e, stackTrace) {
      debugPrint('❌ Error importing CSV: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Lỗi import CSV: $e');
    }
  }

  /// Import từ TXT file
  /// Format giống như text input: front | back hoặc front - back
  static Future<List<Map<String, String>>> importFromTXT(String? filePath, {List<int>? bytes}) async {
    try {
      final content = await readFileContent(filePath, bytes: bytes);
      if (content == null || content.isEmpty) {
        throw Exception('Không thể đọc file hoặc file trống');
      }

      debugPrint('📄 Reading TXT file: $filePath');
      debugPrint('📄 Content length: ${content.length} characters');
      debugPrint('📄 First 200 chars: ${content.substring(0, content.length > 200 ? 200 : content.length)}');
      
      // Parse như text input
      final flashcards = FlashcardParserService.parseTextInput(content);
      
      debugPrint('✅ Parsed ${flashcards.length} flashcards from TXT');
      
      if (flashcards.isEmpty) {
        // Thử parse như CSV nếu TXT parsing fail
        debugPrint('⚠️ TXT parsing returned 0 flashcards, trying CSV format...');
        try {
          final csvFlashcards = await importFromCSV(filePath, bytes: bytes);
          if (csvFlashcards.isNotEmpty) {
            debugPrint('✅ Found ${csvFlashcards.length} flashcards using CSV format');
            return csvFlashcards;
          }
        } catch (e) {
          debugPrint('⚠️ CSV fallback also failed: $e');
        }
        
        throw Exception('Không tìm thấy flashcard nào trong file TXT.\n\n'
            'Vui lòng kiểm tra:\n'
            '• Format: front | back (dùng dấu |)\n'
            '• Hoặc: front - back (dùng dấu -)\n'
            '• Hoặc: front : back (dùng dấu :)\n'
            '• Mỗi dòng một cặp flashcard\n'
            '• File không trống');
      }
      
      return flashcards;
    } catch (e, stackTrace) {
      debugPrint('❌ Error importing TXT: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Lỗi import TXT: $e');
    }
  }

  /// Import từ file (tự động detect format)
  /// Hỗ trợ cả file path và bytes (cho Google Drive)
  /// Returns list of flashcards và file type
  static Future<Map<String, dynamic>> importFromFile({
    String? filePath,
    List<int>? bytes,
    String? fileName,
  }) async {
    try {
      // Determine file type từ extension
      String extension = 'txt'; // Default
      if (fileName != null && fileName.contains('.')) {
        extension = fileName.split('.').last.toLowerCase();
      } else if (filePath != null && filePath.contains('.')) {
        extension = filePath.split('.').last.toLowerCase();
      }
      
      debugPrint('📋 Detected file type: $extension');
      debugPrint('📋 File path: $filePath');
      debugPrint('📋 Has bytes: ${bytes != null && bytes.isNotEmpty}');
      
      List<Map<String, String>> flashcards;
      String fileType;

      switch (extension) {
        case 'csv':
          flashcards = await importFromCSV(filePath, bytes: bytes);
          fileType = 'CSV';
          break;
        case 'txt':
          flashcards = await importFromTXT(filePath, bytes: bytes);
          fileType = 'TXT';
          break;
        default:
          // Try as TXT if unknown extension
          debugPrint('⚠️ Unknown extension: $extension, trying as TXT');
          flashcards = await importFromTXT(filePath, bytes: bytes);
          fileType = 'TXT';
      }

      if (flashcards.isEmpty) {
        throw Exception('Không tìm thấy flashcard nào trong file. Vui lòng kiểm tra định dạng file.');
      }

      return {
        'flashcards': flashcards,
        'fileType': fileType,
        'filePath': filePath,
        'fileName': fileName,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error importing file: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get file size in KB
  static Future<double> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        return size / 1024; // Convert to KB
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error getting file size: $e');
      return 0;
    }
  }

  /// Get file name from path
  static String getFileName(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }

  /// Create example CSV file for download
  static Future<String?> createExampleCSV() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/flashcard_example.csv');
      
      const csvContent = '''front,back
apple,táo
banana,chuối
cat,con mèo
dog,con chó
elephant,con voi''';
      
      await file.writeAsString(csvContent);
      debugPrint('✅ Created example CSV: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error creating example CSV: $e');
      return null;
    }
  }

  /// Create example TXT file for download
  static Future<String?> createExampleTXT() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/flashcard_example.txt');
      
      const txtContent = '''apple | táo
banana - chuối
cat : con mèo
dog | con chó
elephant - con voi''';
      
      await file.writeAsString(txtContent);
      debugPrint('✅ Created example TXT: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error creating example TXT: $e');
      return null;
    }
  }
}

