import 'dart:ui';

import 'package:calendar/screens/calendar_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'memo_detail_screen.dart';
import 'select_family_screen.dart';
import 'settings_screen.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  static const bgColor = Color(0xFFF8F7F6);
  static const primaryColor = Color(0xFF0F172A);
  static const accentColor = Color(0xFFE2B736);
  static const secondaryAccent = Color(0xFFFDE047);
  static const borderColor = Color.fromRGBO(236, 91, 19, 0.05);

  int _selectedNavIndex = 0;

  Stream<List<MemoRecord>> _memoStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream<List<MemoRecord>>.empty();
    }

    return FirebaseFirestore.instance
        .collection('memos')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final memos = snapshot.docs.map(MemoRecord.fromFirestore).toList();
          memos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return memos;
        });
  }

  List<_MemoSection> _buildSections(List<MemoRecord> memos) {
    final sections = <_MemoSection>[];
    String? currentKey;
    List<_MemoItem> currentItems = [];

    for (final memo in memos) {
      final key = _sectionKeyForDate(memo.createdAt);
      if (currentKey != key) {
        if (currentKey != null) {
          sections.add(
            _MemoSection(
              title: currentKey,
              items: List.unmodifiable(currentItems),
            ),
          );
        }
        currentKey = key;
        currentItems = [];
      }

      currentItems.add(
        _MemoItem(
          id: memo.id,
          title: memo.displayTitle,
          dateLabel: _cardDateLabel(memo.createdAt),
          body: memo.body,
        ),
      );
    }

    if (currentKey != null) {
      sections.add(
        _MemoSection(title: currentKey, items: List.unmodifiable(currentItems)),
      );
    }

    return sections;
  }

  String _sectionKeyForDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final memoDay = DateTime(localDate.year, localDate.month, localDate.day);
    final difference = today.difference(memoDay).inDays;

    if (difference == 0) {
      return 'Today';
    }
    if (difference == 1) {
      return 'Yesterday';
    }
    return DateFormat('yyyy.MM.dd').format(localDate);
  }

  String _cardDateLabel(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final memoDay = DateTime(localDate.year, localDate.month, localDate.day);
    final difference = today.difference(memoDay).inDays;

    if (difference == 0 || difference == 1) {
      return DateFormat('h:mm a').format(localDate);
    }
    return DateFormat('yyyy.MM.dd').format(localDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Container(
            width: 430,
            constraints: const BoxConstraints(maxWidth: 430),
            height: double.infinity,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 50,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    children: [
                      const SizedBox(height: 74),
                      Expanded(child: _buildContent()),
                      const SizedBox(height: 94),
                    ],
                  ),
                ),
                Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),
                Positioned(right: 24, bottom: 112, child: _buildFab()),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomNav(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F5).withValues(alpha: 0.8),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: const Center(
            child: Text(
              'Memos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: primaryColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return StreamBuilder<List<MemoRecord>>(
      stream: _memoStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Unable to load memos right now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            ),
          );
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Please sign in to view your memos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            ),
          );
        }

        final sections = _buildSections(snapshot.data ?? const <MemoRecord>[]);
        if (sections.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'No memos yet. Tap the pencil button to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections
                  .map((section) => _buildSection(section))
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(_MemoSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            section.title.toUpperCase(),
            style: const TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...section.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _MemoCard(
              item: item,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemoDetailScreen(
                      memoId: item.id,
                      title: item.title,
                      body: item.body,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFab() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MemoDetailScreen(isCreating: true),
          ),
        );
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [accentColor, secondaryAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.3),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.edit, size: 28, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 17),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _bottomNavItem(
                Icons.chat_bubble_outline,
                'Memo',
                0,
                onTap: () {},
              ),
              _bottomNavItem(
                Icons.people,
                'Family',
                1,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SelectFamilyScreen(),
                    ),
                  );
                },
              ),
              _bottomNavItem(
                Icons.calendar_today,
                'Today',
                2,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalendarScreen()),
                  );
                },
              ),
              _bottomNavItem(
                Icons.settings,
                'Settings',
                3,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem(
    IconData icon,
    String label,
    int index, {
    VoidCallback? onTap,
  }) {
    final selected = index == _selectedNavIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
        onTap?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: selected ? accentColor : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? accentColor : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class MemoRecord {
  const MemoRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  String get displayTitle {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      return trimmedTitle;
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return 'Untitled Memo';
    }

    final firstLine = trimmedBody.split('\n').first.trim();
    if (firstLine.length <= 28) {
      return firstLine;
    }
    return '${firstLine.substring(0, 28).trimRight()}...';
  }

  factory MemoRecord.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = data['createdAt'];

    return MemoRecord(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      createdAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _MemoSection {
  final String title;
  final List<_MemoItem> items;

  const _MemoSection({required this.title, required this.items});
}

class _MemoItem {
  final String id;
  final String title;
  final String dateLabel;
  final String body;

  const _MemoItem({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.body,
  });
}

class _MemoCard extends StatelessWidget {
  final _MemoItem item;
  final VoidCallback? onTap;

  const _MemoCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _MemoScreenState.borderColor),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _MemoScreenState.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                item.dateLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );

    final effectiveCard = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );

    return effectiveCard;
  }
}
