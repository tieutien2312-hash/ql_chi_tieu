import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  List<dynamic> _users = [];
  List<dynamic> _sessions = [];
  List<dynamic> _auditLogs = [];
  Map<String, dynamic>? _securityStats;
  Map<String, dynamic>? _securitySettings;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sessionExpController = TextEditingController();
  final TextEditingController _maxFailedLoginController = TextEditingController();
  final TextEditingController _minPassLengthController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final userResult = await ApiService.getAdminUsers(search: _searchController.text.trim());
      final sessions = await ApiService.getAdminSessions();
      final stats = await ApiService.getSecurityStatistics();
      final settings = await ApiService.getSecuritySettings();
      final auditLogs = await ApiService.getAuditLogs();

      setState(() {
        _users = userResult['items'] ?? [];
        _sessions = sessions;
        _securityStats = stats;
        _securitySettings = settings;
        _auditLogs = auditLogs;
        _isLoading = false;

        if (_securitySettings != null) {
          _sessionExpController.text = (_securitySettings!['sessionExpirationMinutes'] ?? '').toString();
          _maxFailedLoginController.text = (_securitySettings!['maxFailedLoginAttempts'] ?? '').toString();
          _minPassLengthController.text = (_securitySettings!['passwordMinimumLength'] ?? '').toString();
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Đăng xuất'),
            content: const Text('Bạn có chắc chắn muốn đăng xuất tài khoản Admin không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đăng xuất', style: TextStyle(color: AppTheme.errorRed))),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await ApiService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _promptReasonAndExecute(String userId, String actionType) async {
    final reasonController = TextEditingController();
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(actionType == 'lock' ? 'Khóa tài khoản' : 'Vô hiệu hóa tài khoản'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Vui lòng nhập lý do thực hiện thao tác quản trị này:'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Lý do'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận', style: TextStyle(color: AppTheme.errorRed))),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      bool success = false;
      if (actionType == 'lock') {
        success = await ApiService.lockUser(userId, reasonController.text.trim());
      } else {
        success = await ApiService.deactivateUser(userId, reasonController.text.trim());
      }
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thành công!')));
        _loadAdminData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thất bại.')));
      }
    }
  }

  Future<void> _unlockUser(String userId) async {
    bool success = await ApiService.unlockUser(userId);
    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã mở khóa tài khoản!')));
      _loadAdminData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mở khóa thất bại.')));
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    bool success = await ApiService.revokeSession(sessionId, 'Quản trị viên thu hồi phiên.');
    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thu hồi phiên đăng nhập!')));
      _loadAdminData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thu hồi thất bại.')));
    }
  }

  Future<void> _saveSettings() async {
    Map<String, dynamic> newSettings = {
      'sessionExpirationMinutes': int.tryParse(_sessionExpController.text) ?? 60,
      'maxFailedLoginAttempts': int.tryParse(_maxFailedLoginController.text) ?? 5,
      'passwordMinimumLength': int.tryParse(_minPassLengthController.text) ?? 6,
    };
    bool success = await ApiService.updateSecuritySettings(newSettings);
    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật cấu hình bảo mật thành công!')));
      _loadAdminData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thất bại.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Bảng Quản Trị Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.errorRed),
            onPressed: _handleLogout,
            tooltip: 'Đăng xuất',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryCyanDark,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryCyan,
          tabs: const [
            Tab(text: 'Tài khoản'),
            Tab(text: 'Phiên đăng nhập'),
            Tab(text: 'Bảo mật & Cấu hình'),
            Tab(text: 'Nhật ký Audit'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(),
                _buildSessionsTab(),
                _buildSecurityTab(),
                _buildAuditLogsTab(),
              ],
            ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Tìm kiếm theo Tên hoặc Email',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _loadAdminData(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loadAdminData,
                child: const Text('Tìm'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? const Center(child: Text('Không tìm thấy tài khoản nào.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final u = _users[index];
                    final userId = u['id']?.toString() ?? '';
                    final email = u['email'] ?? '';
                    final username = u['username'] ?? '';
                    final status = u['status'] ?? 'Active';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryCyan.withOpacity(0.2),
                          child: Text(username.isNotEmpty ? username[0].toUpperCase() : 'U'),
                        ),
                        title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$email\nTrạng thái: $status'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'lock') _promptReasonAndExecute(userId, 'lock');
                            if (val == 'unlock') _unlockUser(userId);
                            if (val == 'deactivate') _promptReasonAndExecute(userId, 'deactivate');
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'lock', child: Text('Khóa tài khoản', style: TextStyle(color: AppTheme.errorRed))),
                            const PopupMenuItem(value: 'unlock', child: Text('Mở khóa tài khoản', style: TextStyle(color: AppTheme.successGreen))),
                            const PopupMenuItem(value: 'deactivate', child: Text('Vô hiệu hóa', style: TextStyle(color: Colors.orange))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSessionsTab() {
    return _sessions.isEmpty
        ? const Center(child: Text('Không có phiên đăng nhập nào.'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final s = _sessions[index];
              final sessionId = s['id']?.toString() ?? '';
              final device = s['deviceName'] ?? 'Thiết bị';
              final ip = s['ipAddress'] ?? 'IP';
              final isActive = s['isActive'] ?? true;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.devices, color: AppTheme.primaryCyan),
                  title: Text(device, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('IP: $ip\nTrạng thái: ${isActive ? 'Đang hoạt động' : 'Đã thu hồi'}'),
                  isThreeLine: true,
                  trailing: isActive
                      ? TextButton(
                          onPressed: () => _revokeSession(sessionId),
                          child: const Text('Thu hồi', style: TextStyle(color: AppTheme.errorRed)),
                        )
                      : const Text('Đã thu hồi', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ),
              );
            },
          );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thống kê bảo mật hệ thống', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Đăng nhập thành công', '${_securityStats?['successfulLogins'] ?? 0}', Colors.green),
              _buildStatCard('Đăng nhập thất bại', '${_securityStats?['failedLogins'] ?? 0}', Colors.red),
              _buildStatCard('Tài khoản bị khóa', '${_securityStats?['lockedAccountsCount'] ?? 0}', Colors.orange),
              _buildStatCard('Phiên hoạt động', '${_securityStats?['activeSessionsCount'] ?? 0}', AppTheme.primaryCyan),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Cấu hình bảo mật hệ thống', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _sessionExpController,
                    decoration: const InputDecoration(labelText: 'Thời gian hết hạn Session (phút)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _maxFailedLoginController,
                    decoration: const InputDecoration(labelText: 'Số lần đăng nhập sai tối đa'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _minPassLengthController,
                    decoration: const InputDecoration(labelText: 'Độ dài mật khẩu tối thiểu'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Lưu cấu hình bảo mật'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildAuditLogsTab() {
    return _auditLogs.isEmpty
        ? const Center(child: Text('Không có nhật ký hoạt động nào.'))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _auditLogs.length,
            itemBuilder: (context, index) {
              final log = _auditLogs[index];
              final action = log['action'] ?? 'Hành động';
              final time = log['createdAt'] ?? log['timestamp'] ?? '';
              final details = log['details'] ?? log['reason'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.security, color: AppTheme.primaryCyanDark),
                  title: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('$details\nThời gian: $time', style: const TextStyle(fontSize: 12)),
                  isThreeLine: true,
                ),
              );
            },
          );
  }
}
