import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  final List<String> _availableColors = [
    '#F97316', // Orange
    '#3B82F6', // Blue
    '#EC4899', // Pink
    '#10B981', // Emerald
    '#8B5CF6', // Purple
    '#EF4444', // Red
    '#0EA5E9', // Sky Blue
    '#F59E0B', // Amber
    '#6366F1', // Indigo
    '#6B7280', // Gray
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final cats = await ApiService.getCategories();
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'directions_car':
        return Icons.directions_car;
      case 'receipt':
        return Icons.receipt;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'favorite':
        return Icons.favorite;
      case 'school':
        return Icons.school;
      case 'work':
        return Icons.work;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'attach_money':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryCyan;
    }
  }

  void _showAddEditCategoryDialog({CategoryModel? categoryToEdit}) {
    final isEditing = categoryToEdit != null;
    final nameController = TextEditingController(text: categoryToEdit?.name ?? '');
    String selectedType = categoryToEdit?.type ?? (_tabController.index == 0 ? 'EXPENSE' : 'INCOME');
    String selectedColor = categoryToEdit?.color ?? _availableColors[0];
    String selectedIcon = categoryToEdit?.icon ?? 'restaurant';

    final List<Map<String, String>> iconOptions = [
      {'name': 'restaurant', 'label': 'Ăn uống'},
      {'name': 'shopping_bag', 'label': 'Mua sắm'},
      {'name': 'directions_car', 'label': 'Di chuyển'},
      {'name': 'receipt', 'label': 'Hóa đơn'},
      {'name': 'sports_esports', 'label': 'Giải trí'},
      {'name': 'favorite', 'label': 'Sức khỏe'},
      {'name': 'school', 'label': 'Học tập'},
      {'name': 'work', 'label': 'Lương/Công việc'},
      {'name': 'card_giftcard', 'label': 'Thưởng/Quà'},
      {'name': 'attach_money', 'label': 'Thu nhập khác'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Chỉnh sửa danh mục' : 'Thêm danh mục mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên danh mục*'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Loại danh mục', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Chi tiêu')),
                            selected: selectedType == 'EXPENSE',
                            selectedColor: Colors.red.shade100,
                            onSelected: (selected) {
                              setDialogState(() => selectedType = 'EXPENSE');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Thu nhập')),
                            selected: selectedType == 'INCOME',
                            selectedColor: Colors.green.shade100,
                            onSelected: (selected) {
                              setDialogState(() => selectedType = 'INCOME');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableColors.map((hex) {
                        final color = _parseColor(hex);
                        final isSelected = selectedColor == hex;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = hex),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 3),
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Biểu tượng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedIcon,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: iconOptions.map((item) {
                        return DropdownMenuItem<String>(
                          value: item['name'],
                          child: Row(
                            children: [
                              Icon(_getIconData(item['name']!), color: _parseColor(selectedColor)),
                              const SizedBox(width: 12),
                              Text(item['label']!),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedIcon = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.white),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên danh mục!')));
                      return;
                    }

                    bool isDuplicate = _categories.any((c) => c.name.toLowerCase() == name.toLowerCase() && c.type == selectedType && c.id != categoryToEdit?.id);
                    if (isDuplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tên danh mục này đã tồn tại trong cùng loại!')));
                      return;
                    }

                    if (isEditing) {
                      final updated = categoryToEdit.copyWith(
                        name: name,
                        type: selectedType,
                        color: selectedColor,
                        icon: selectedIcon,
                      );
                      await ApiService.updateCategory(updated);
                    } else {
                      final newCat = CategoryModel(
                        name: name,
                        type: selectedType,
                        color: selectedColor,
                        icon: selectedIcon,
                      );
                      await ApiService.insertCategory(newCat);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadCategories();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEditing ? 'Đã cập nhật danh mục thành công!' : 'Đã thêm danh mục thành công!')),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Lưu' : 'Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategory(CategoryModel category) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text('Bạn có chắc chắn muốn xóa danh mục "${category.name}" không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: AppTheme.errorRed))),
            ],
          ),
        ) ??
        false;

    if (confirm && category.id != null) {
      await ApiService.deleteCategory(category.id, 'Khác');
      _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa danh mục thành công!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = _categories.where((c) => c.type == 'EXPENSE').toList();
    final incomeCategories = _categories.where((c) => c.type == 'INCOME').toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Quản lý danh mục'),
        backgroundColor: AppTheme.surfaceWhite,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryCyanDark,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryCyan,
          tabs: const [
            Tab(text: 'Chi tiêu'),
            Tab(text: 'Thu nhập'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(expenseCategories),
                _buildCategoryList(incomeCategories),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditCategoryDialog(),
        backgroundColor: AppTheme.primaryCyan,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList(List<CategoryModel> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Text('Chưa có danh mục nào.', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final color = _parseColor(cat.color);
        final icon = _getIconData(cat.icon);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.borderLight)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            subtitle: Text(cat.type == 'EXPENSE' ? 'Danh mục Chi tiêu' : 'Danh mục Thu nhập', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryCyanDark),
                  onPressed: () => _showAddEditCategoryDialog(categoryToEdit: cat),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                  onPressed: () => _confirmDeleteCategory(cat),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
