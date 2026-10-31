import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final VoidCallback onNotificationTap;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final String trimmedName = userName.trim();
    final List<String> nameParts = trimmedName.split(' ').where((part) => part.isNotEmpty).toList();

    String firstLetter = 'U';
    if (nameParts.isNotEmpty) {
      if (nameParts.length == 1) {
        firstLetter = nameParts.first[0].toUpperCase();
      } else {
        firstLetter = '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
      }
    }

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F8FB),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            firstLetter,
            style: const TextStyle(
              color: Color(0xFF00869B),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Moni đồng hành cùng bạn',
                style: TextStyle(
                  color: Color(0xFF75868D),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Chào $userName!',
                    style: const TextStyle(
                      color: Color(0xFF142F38),
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Stack(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE8EFF2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF142F38),
                  size: 22,
                ),
                onPressed: onNotificationTap,
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
