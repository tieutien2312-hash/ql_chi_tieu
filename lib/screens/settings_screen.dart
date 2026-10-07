import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openNotificationSettings() async {
    const platform = MethodChannel('com.example.ql_chi_tieu/notification');
    try {
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      // Fallback or print error
      debugPrint('Error opening notification settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Permission Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active, color: Colors.indigo, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Quyền Đọc Thông Báo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Để ứng dụng có thể tự động ghi nhận biến động số dư từ các ngân hàng và ví điện tử (Vietcombank, MB Bank, Momo, ZaloPay...), bạn cần cấp quyền truy cập thông báo.',
                    style: TextStyle(color: Colors.black87, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hướng dẫn:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
                        ),
                        SizedBox(height: 4),
                        Text('1. Nhấn nút "Cấp quyền" bên dưới.'),
                        Text('2. Tìm ứng dụng "ql_chi_tieu" trong danh sách.'),
                        Text('3. Bật công tắc cho phép truy cập thông báo.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ngân hàng & Ví hỗ trợ tự động',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Về ứng dụng',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Phiên bản: 1.0.0'),
                  Text('Công nghệ: Flutter, Android Native Service, SQLite, fl_chart'),
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
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}
