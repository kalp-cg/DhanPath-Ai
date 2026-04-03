import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/pdf_statement_parser.dart';
import '../providers/transaction_provider.dart';

class PdfUploadScreen extends StatefulWidget {
  const PdfUploadScreen({Key? key}) : super(key: key);

  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen> {
  String _selectedBank = 'HDFC Bank';
  bool _isProcessing = false;
  String? _statusMessage;
  int? _importedCount;
  
  PlatformFile? _selectedFile;

  final List<String> _supportedBanks = [
    'HDFC Bank',
    'SBI',
    'ICICI Bank',
    'Axis Bank'
  ];

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = result.files.single;
          _statusMessage = null; // Clear old success states
          _importedCount = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error picking file: $e';
        });
      }
    }
  }

  Future<void> _extractTransactions() async {
    if (_selectedFile == null || _selectedFile!.path == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Parsing ${_selectedFile!.name} instantly locally...';
      _importedCount = null;
    });

    try {
      final int count = await PdfStatementParser().parseAndImportStatement(
        _selectedFile!.path!,
        _selectedBank,
      );

        int bankTotal = 0;
        int lastMonthTotal = 0;

      if (mounted) {
        // Keep list screens in sync after direct DB insert from statement importer.
        await context.read<TransactionProvider>().loadTransactions();

          final provider = context.read<TransactionProvider>();
          final now = DateTime.now();
          final lastMonth = now.month == 1 ? 12 : now.month - 1;
          final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;

          final bankTxns = provider.allTransactions.where(
            (t) => (t.bankName ?? '').toLowerCase() == _selectedBank.toLowerCase(),
          );

          bankTotal = bankTxns.length;
          lastMonthTotal = bankTxns.where(
            (t) => t.date.year == lastMonthYear && t.date.month == lastMonth,
          ).length;
      }

      setState(() {
        _isProcessing = false;
        _importedCount = count;
        _statusMessage = count > 0 
              ? 'Imported $count new transactions. ${_selectedBank}: total $bankTotal, last month $lastMonthTotal.'
              : 'No new rows inserted. ${_selectedBank}: total $bankTotal, last month $lastMonthTotal.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Extraction Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), 
      appBar: AppBar(
        title: const Text('Offline PDF Parser', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Hero Icon
            const Icon(
              Icons.document_scanner_rounded,
              size: 70,
              color: Colors.tealAccent,
            ),
            const SizedBox(height: 20),
            const Text(
              'Bulk Bank Statement Importer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a PDF. Our offline engine extracts all rows in < 1 second. Duplicates are auto-skipped.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            
            // 1. Bank Selector
            const Text("1. Select Statement Bank", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBank,
                  dropdownColor: const Color(0xFF161B22),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  isExpanded: true,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedBank = newValue!;
                    });
                  },
                  items: _supportedBanks.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 2. File Selection Card
            const Text("2. Upload PDF Document", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _isProcessing ? null : _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedFile != null ? Colors.teal.withOpacity(0.1) : const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedFile != null ? Colors.tealAccent : Colors.grey.withOpacity(0.2),
                    width: _selectedFile != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedFile != null ? Icons.picture_as_pdf_rounded : Icons.folder_open_rounded,
                      color: _selectedFile != null ? Colors.tealAccent : Colors.white70,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile != null ? _selectedFile!.name : 'Tap to Browse Files',
                            style: TextStyle(
                              color: _selectedFile != null ? Colors.tealAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedFile != null)
                             Text('\${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB • Ready', 
                                style: const TextStyle(color: Colors.white54, fontSize: 12)
                             ),
                        ],
                      ),
                    ),
                    if (_selectedFile != null)
                      const Icon(Icons.check_circle_rounded, color: Colors.tealAccent),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // 3. Extractor Button (The Magic)
            ElevatedButton(
              onPressed: (_selectedFile == null || _isProcessing) ? null : _extractTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent.shade700,
                disabledBackgroundColor: Colors.teal.withOpacity(0.2),
                disabledForegroundColor: Colors.white30,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: _isProcessing 
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Extracting instantly...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded),
                        SizedBox(width: 8),
                        Text('Extract Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),

            const SizedBox(height: 32),

            // Success / Status Banner
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: _importedCount != null && _importedCount! > 0 
                      ? Colors.green.withOpacity(0.15) 
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _importedCount != null && _importedCount! > 0 
                        ? Colors.greenAccent 
                        : Colors.orangeAccent,
                    width: 1.5
                  )
                ),
                child: Row(
                  children: [
                    Icon(
                      _importedCount != null && _importedCount! > 0 ? Icons.check_circle_outline : Icons.info_outline,
                      color: _importedCount != null && _importedCount! > 0 ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _importedCount != null && _importedCount! > 0 
                              ? Colors.greenAccent 
                              : Colors.orangeAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
