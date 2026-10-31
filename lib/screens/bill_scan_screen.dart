import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BillScanScreen extends StatefulWidget {
  const BillScanScreen({super.key});

  @override
  State<BillScanScreen> createState() => _BillScanScreenState();
}

class _BillScanScreenState extends State<BillScanScreen> {
  static const String _geminiApiKey = 'vv';

  File? _imageFile;
  bool _isScanning = false;
  bool _scannedSuccess = false;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  dynamic _selectedAccountId;
  String _selectedCategory = 'Khác';
  String _selectedType = 'EXPENSE';

  List<Account> _accounts = [];
  List<CategoryModel> _categories = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final accs = await ApiService.getAccounts();
    final cats = await ApiService.getCategories();
    if (mounted) {
      setState(() {
        _accounts = accs;
        _categories = cats;
        if (accs.isNotEmpty) _selectedAccountId = accs.first.id;
        if (cats.isNotEmpty) _selectedCategory = cats.first.name;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Chọn ảnh và nén để upload nhanh, tránh nghẽn tải
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Nén ảnh nhẹ để ML Kit đọc mượt
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _isScanning = true;
          _scannedSuccess = false;
        });

        // 1. Dùng ML Kit OCR ngay trên máy để lấy text cực nhanh (~0.2s)
        final inputImage = InputImage.fromFilePath(pickedFile.path);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        await textRecognizer.close();

        // 2. Gửi chuỗi text thô sang Gemini để parse JSON tức thì
        await _analyzeReceiptTextWithGemini(recognizedText.text);

        if (mounted) {
          setState(() {
            _isScanning = false;
            _scannedSuccess = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi quét hóa đơn: $e')),
        );
      }
    }
  }

  // Gửi ảnh sang Gemini AI kèm cơ chế tự động thử lại khi gặp lỗi server 503
  Future<void> _analyzeReceiptTextWithGemini(String rawReceiptText) async {
    try {
      // Nếu OCR không thấy chữ nào
      if (rawReceiptText.trim().isEmpty) {
        throw Exception('Không nhận diện được nội dung chữ trên ảnh!');
      }

      final model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: _geminiApiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.1,
          maxOutputTokens: 10000, // Tăng lên 1000 để không bao giờ bị cắt ngắn giữa chừng
        ),
      );

      final prompt = '''
Phân tích văn bản hóa đơn sau và trích xuất thành JSON:
"""
$rawReceiptText
"""

JSON format:
{
  "title": "Tên thương hiệu/quán/nội dung giao dịch chính",
  "amount": Số tiền thanh toán cuối cùng (số nguyên),
  "category": "Ăn uống" hoặc "Mua sắm" hoặc "Di chuyển" hoặc "Hóa đơn" hoặc "Khác"
}
''';

      GenerateContentResponse? response;
      int retries = 2;

      while (retries > 0) {
        try {
          // Gửi text qua mạng chỉ mất vài mili-giây
          response = await model.generateContent([Content.text(prompt)]);
          break;
        } catch (e) {
          retries--;
          if (retries == 0) rethrow;
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }

      final responseText = response?.text;
      if (responseText != null && responseText.isNotEmpty) {
        // Loại bỏ markdown code block nếu có
        String cleanJson = responseText.trim();
        if (cleanJson.startsWith('```json')) {
          cleanJson = cleanJson.substring(7);
        }
        if (cleanJson.startsWith('```')) {
          cleanJson = cleanJson.substring(3);
        }
        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        }
        cleanJson = cleanJson.trim();

        final Map<String, dynamic> data = jsonDecode(cleanJson);

        double detectedAmount = 0.0;
        if (data['amount'] != null) {
          detectedAmount = double.tryParse(data['amount'].toString()) ?? 0.0;
        }

        String detectedTitle = data['title']?.toString() ?? 'Chi tiêu hóa đơn';
        String detectedCategory = data['category']?.toString() ?? 'Khác';

        String matchedCategory = 'Khác';
        for (var cat in _categories) {
          if (cat.name.toLowerCase() == detectedCategory.toLowerCase()) {
            matchedCategory = cat.name;
            break;
          }
        }
        if (matchedCategory == 'Khác' && _categories.isNotEmpty) {
          matchedCategory = _categories.first.name;
        }

        if (mounted) {
          setState(() {
            _amountController.text = detectedAmount > 0 ? detectedAmount.toStringAsFixed(0) : '0';
            _descriptionController.text = detectedTitle;
            _selectedCategory = matchedCategory;
            _selectedType = 'EXPENSE';
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi AI parse text: $e');
      rethrow;
    }
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '').replaceAll('.', '')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ!')));
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn tài khoản/ví!')));
      return;
    }

    final currentTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final tx = TransactionModel(
      accountId: _selectedAccountId!,
      type: _selectedType,
      amount: amount,
      balanceAfter: 0,
      description: _descriptionController.text.trim().isEmpty ? 'Giao dịch quét bill' : _descriptionController.text.trim(),
      transactionTime: currentTime,
      source: 'bill_scan',
      category: _selectedCategory,
    );

    await ApiService.insertTransaction(tx);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lưu giao dịch từ bill thành công!')));
      Navigator.pop(context, true);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chọn nguồn ảnh hóa đơn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: AppTheme.primaryCyan, child: Icon(Icons.camera_alt, color: Colors.white)),
                title: const Text('Chụp ảnh trực tiếp'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.photo_library, color: Colors.white)),
                title: const Text('Chọn từ thư viện điện thoại'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Quét Bill Hóa Đơn (AI Vision)'),
        backgroundColor: AppTheme.surfaceWhite,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: _imageFile == null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.document_scanner_outlined, size: 54, color: AppTheme.primaryCyan),
                    const SizedBox(height: 12),
                    const Text('Chụp hoặc chọn ảnh hóa đơn để AI tự nhận diện', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.white),
                      onPressed: _showImageSourceDialog,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Quét hóa đơn ngay'),
                    ),
                  ],
                ),
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_imageFile!, fit: BoxFit.cover),
                    if (_isScanning)
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppTheme.primaryCyan),
                              SizedBox(height: 12),
                              Text('AI đang đọc và phân tích bill...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        backgroundColor: AppTheme.primaryCyan,
                        foregroundColor: Colors.white,
                        onPressed: _showImageSourceDialog,
                        child: const Icon(Icons.refresh),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_scannedSuccess) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kết quả nhận diện AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Chính xác cao', style: TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số tiền (VNĐ)*'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Tên giao dịch / Cửa hàng*'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<dynamic>(
                      value: _selectedAccountId,
                      decoration: const InputDecoration(labelText: 'Tài khoản / Ví*'),
                      items: _accounts.map((acc) {
                        return DropdownMenuItem<dynamic>(
                          value: acc.id,
                          child: Text('${acc.bankName} (${acc.accountNumber})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedAccountId = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Danh mục tự động'),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat.name,
                          child: Text(cat.name),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val!),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCyan,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _saveTransaction,
                        child: const Text('Xác nhận & Lưu giao dịch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_imageFile != null && !_isScanning) ...[
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.white),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.document_scanner),
                  label: const Text('Quét lại hóa đơn'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
