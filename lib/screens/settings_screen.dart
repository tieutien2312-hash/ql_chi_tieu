import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/test_seeder.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openNotificationSettings() async {
    const platform = MethodChannel('com.example.ql_chi_tieu/notification');
    try {
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
    }
  }

  void _loadSampleData(BuildContext context) async {
    try {
      await TestSeeder.insertSampleData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã nạp dữ liệu mẫu thành công! Hãy kiểm tra Trang chủ và Lịch sử giao dịch.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi nạp dữ liệu mẫu: $e')),
        );
      }
    }
  }

  void _clearData(BuildContext context) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa toàn bộ dữ liệu'),
            content: const Text('Bạn có chắc chắn muốn xóa tất cả tài khoản và giao dịch không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: AppTheme.errorRed))),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await TestSeeder.clearTestData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa toàn bộ dữ liệu thành công!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Testing Tools Card (Only visible in Debug mode)
          if (kDebugMode) ...[
            Card(
              elevation: 1,
              color: Colors.orange.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.orange.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.science, color: Colors.deepOrange, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Công cụ Test (Chỉ hiển thị khi Debug)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nạp sẵn bộ dữ liệu mẫu (Vietcombank, MB Bank, Momo, giao dịch Thu/Chi) để kiểm tra nhanh biểu đồ thống kê và lịch sử giao dịch.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _loadSampleData(context),
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Nạp dữ liệu mẫu'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorRed,
                              side: const BorderSide(color: AppTheme.errorRed),
                            ),
                            onPressed: () => _clearData(context),
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('Xóa dữ liệu'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Permission Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active, color: AppTheme.primaryCyan, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Quyền Đọc Thông Báo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Để ứng dụng có thể tự động ghi nhận biến động số dư từ các ngân hàng và ví điện tử (Vietcombank, MB Bank, Momo, ZaloPay...), bạn cần cấp quyền truy cập thông báo.',
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hướng dẫn:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCyanDark),
                        ),
                        SizedBox(height: 4),
                        Text('1. Nhấn nút "Cấp quyền" bên dưới.', style: TextStyle(color: AppTheme.textPrimary)),
                        Text('2. Tìm ứng dụng "ql_chi_tieu" trong danh sách.', style: TextStyle(color: AppTheme.textPrimary)),
                        Text('3. Bật công tắc cho phép truy cập thông báo.', style: TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryCyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _openNotificationSettings,
                      icon: const Icon(Icons.settings),
                      label: const Text('Cấp quyền (Mở Cài đặt Android)', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Supported Banks Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ngân hàng & Ví hỗ trợ tự động',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _buildBankItem('Vietcombank', 'VCB Digibank'),
                  _buildBankItem('MB Bank', 'App MBBank'),
                  _buildBankItem('Agribank', 'Agribank E-Mobile Banking'),
                  _buildBankItem('BIDV', 'BIDV SmartBanking'),
                  _buildBankItem('Ví Momo', 'Momo App'),
                  _buildBankItem('ZaloPay', 'ZaloPay Wallet'),
                  _buildBankItem('Techcombank', 'Techcombank Mobile'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // About App
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.borderLight),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Về ứng dụng',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 8),
                  Text('Phiên bản: 1.0.0', style: TextStyle(color: AppTheme.textSecondary)),
                  Text('Công nghệ: Flutter, Android Native Service, SQLite, fl_chart', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankItem(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
