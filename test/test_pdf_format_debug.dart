import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Extract text from actual SBI PDF to analyze the format', () async {
    final pdfs = [
      '/home/xkalp/Downloads/1775033540760WyrmrCZrvAElbRqn.pdf',
      '/home/xkalp/Downloads/1775035661828QCHvSViOlmAKd7Hm.pdf',
    ];

    for (var path in pdfs) {
      final file = File(path);
      if (!await file.exists()) continue;

      print('\n\n=== EXTRACTING: $path ===');
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      
      final lines = text.split('\n');
      int count = 0;
      for (var line in lines) {
        if (line.trim().isNotEmpty) {
          print(line.trim());
          count++;
          if (count > 20) break; // just need a few transaction lines
        }
      }
      document.dispose();
    }
  });
}
