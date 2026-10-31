import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  String _userEmail = 'thanhvien@moni.vn';
  String _fullName = 'Nguyễn Văn A';
  String _username = 'nguyenvana';
  String _selectedAvatar = 'young_male';
  bool _isNotificationPermissionGranted = false;

  static const platform = MethodChannel('com.example.ql_chi_tieu/notification');

  final List<Map<String, dynamic>> _sampleAvatars = [
    {'id': 'young_male', 'label': 'Nam trẻ', 'icon': Icons.boy, 'color': Colors.blue},
    {'id': 'young_female', 'label': 'Nữ trẻ', 'icon': Icons.girl, 'color': Colors.pink},
    {'id': 'elder_male', 'label': 'Nam trung niên', 'icon': Icons.man, 'color': Colors.indigo},
    {'id': 'elder_female', 'label': 'Nữ trung niên', 'icon': Icons.woman, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Tự động kiểm tra lại quyền khi người dùng từ cài đặt Android quay lại App
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  Future<void> _checkNotificationPermission() async {
    try {
      final bool isGranted = await platform.invokeMethod('isNotificationPermissionGranted') ?? false;
      debugPrint('Notification Permission Status: $isGranted'); // Debug ở đây
      if (mounted) {
        setState(() {
          _isNotificationPermissionGranted = isGranted;
        });
      }
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userEmail = prefs.getString('user_email') ?? 'thanhvien@moni.vn';
        _fullName = prefs.getString('user_fullname') ?? 'Nguyễn Văn A';
        _username = prefs.getString('user_username') ?? 'nguyenvana';
        _selectedAvatar = prefs.getString('user_avatar') ?? 'young_male';
      });
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _fullName);
    final usernameController = TextEditingController(text: _username);

    bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Họ và tên'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Tên tài khoản (Username)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppSettingsController.instance.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final newName = nameController.text.trim();
      final newUsername = usernameController.text.trim();
      if (newName.isNotEmpty && newUsername.isNotEmpty) {
        setState(() {
          _fullName = newName;
          _username = newUsername;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_fullname', newName);
        await prefs.setString('user_username', newUsername);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
          );
        }
      }
    }
  }

  Future<void> _showAvatarPickerModal() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn hình đại diện (Avatar)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
              ),
              itemCount: _sampleAvatars.length,
              itemBuilder: (context, index) {
                final av = _sampleAvatars[index];
                bool isSelected = _selectedAvatar == av['id'];
                final primaryColor = AppSettingsController.instance.primaryColor;
                return InkWell(
                    onTap: () async {
                    setState(() => _selectedAvatar = av['id'] as String);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('user_avatar', av['id'] as String);
                    if (mounted) Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor.withOpacity(0.15) : AppTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? primaryColor : AppTheme.borderLight, width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: (av['color'] as Color).withOpacity(0.2),
                          child: Icon(av['icon'] as IconData, color: av['color'] as Color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            av['label'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSelected ? primaryColor : AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
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

  @override
  Widget build(BuildContext context) {
    final currentAvatarInfo = _sampleAvatars.firstWhere(
          (a) => a['id'] == _selectedAvatar,
      orElse: () => _sampleAvatars[0],
    );

    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        final settings = AppSettingsController.instance;
        final primaryColor = settings.primaryColor;

        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User Profile Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderLight)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: currentAvatarInfo['color'].withOpacity(0.2),
                            child: Icon(currentAvatarInfo['icon'], size: 44, color: currentAvatarInfo['color']),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _showAvatarPickerModal,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$_username · $_userEmail',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Thành viên (User)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _showEditProfileDialog,
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Chỉnh sửa hồ sơ'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorRed,
                                side: const BorderSide(color: AppTheme.errorRed),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _handleLogout,
                              icon: const Icon(Icons.logout, size: 18),
                              label: const Text('Đăng xuất'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // App Customization Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderLight)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.palette_outlined, color: primaryColor, size: 24),
                          const SizedBox(width: 10),
                          const Text(
                            'Tùy biến giao diện',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Cỡ chữ hiển thị', style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textPrimary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('Nhỏ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          Expanded(
                            child: Slider(
                              value: settings.fontSizeScale,
                              min: 0.85,
                              max: 1.3,
                              divisions: 3,
                              activeColor: primaryColor,
                              onChanged: (val) => settings.updateFontSize(val),
                            ),
                          ),
                          const Text('Lớn', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('Màu chủ đạo (Accent Color)', style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textPrimary, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildColorOption('Cyan', AppTheme.primaryCyan),
                          _buildColorOption('Indigo', const Color(0xFF6366F1)),
                          _buildColorOption('Emerald', AppTheme.successGreen),
                          _buildColorOption('Orange', const Color(0xFFF97316)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
                      Row(
                        children: [
                          Icon(Icons.notifications_active, color: primaryColor, size: 24),
                          const SizedBox(width: 10),
                          const Text(
                            'Quyền Đọc Thông Báo',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isNotificationPermissionGranted
                            ? 'Ứng dụng đã được cấp quyền đọc thông báo để tự động ghi nhận biến động số dư.'
                            : 'Bật quyền đọc thông báo để tự động ghi nhận biến động số dư từ các ngân hàng.',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _openNotificationSettings,
                          icon: const Icon(Icons.settings),
                          label: const Text('Mở Cài đặt thông báo Android'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // About App
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderLight)),
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Về ứng dụng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                      SizedBox(height: 6),
                      Text('Phiên bản: 1.0.0 (ASP.NET Core Backend)', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorOption(String name, Color color) {
    bool isSelected = AppSettingsController.instance.accentColorName == name;
    return GestureDetector(
      onTap: () => AppSettingsController.instance.updateAccentColor(name),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Colors.black54 : Colors.transparent, width: 3),
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}