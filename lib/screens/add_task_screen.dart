import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({
    Key? key,
    this.initialTitle,
    this.initialNotes,
    this.initialDate,
    this.initialTime,
    this.initialCategory,
    this.initialReminderEnabled,
  }) : super(key: key);

  final String? initialTitle;
  final String? initialNotes;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final String? initialCategory;
  final bool? initialReminderEnabled;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  static const _card = Color(0xFFFAF6EB);
  static const _labelColor = Color(0xFFB08F4C);
  static const _primaryColor = Color(0xFF0F172A);
  static const _accentColor = Color(0xFFE2B736);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _reminderEnabled = true;
  bool _isSaving = false;
  int _selectedCategoryIndex = 0;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  static const _categories = [
    {'label': 'Education', 'color': Color(0xFF3B82F6)},
    {'label': 'Family', 'color': Color(0xFF8B5CF6)},
    {'label': 'Leisure', 'color': Color(0xFFF97316)},
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _titleController.text = widget.initialTitle?.trim() ?? '';
    _notesController.text = widget.initialNotes?.trim() ?? '';
    _selectedDate =
        widget.initialDate ?? DateTime(now.year, now.month, now.day);
    _selectedTime =
        widget.initialTime ?? TimeOfDay(hour: now.hour, minute: now.minute);
    _reminderEnabled = widget.initialReminderEnabled ?? true;

    final initialCategory = widget.initialCategory?.trim().toLowerCase();
    final matchedIndex = _categories.indexWhere(
      (category) =>
          (category['label'] as String).toLowerCase() == initialCategory,
    );
    if (matchedIndex >= 0) {
      _selectedCategoryIndex = matchedIndex;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _accentColor,
              onPrimary: Colors.white,
              onSurface: _primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final initialTime = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: _accentColor,
                onPrimary: Colors.white,
                onSurface: _primaryColor,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _dateText() {
    if (_selectedDate == null) return 'Select date';
    return DateFormat('MM/dd/yyyy').format(_selectedDate!);
  }

  String _timeText() {
    if (_selectedTime == null) return 'Select time';
    final hour = _selectedTime!.hour.toString().padLeft(2, '0');
    final minute = _selectedTime!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime _buildStartDateTime() {
    final date = _selectedDate!;
    final time = _selectedTime!;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _selectedEventType() {
    return (_categories[_selectedCategoryIndex]['label'] as String)
        .toLowerCase();
  }

  Future<List<String>> _loadParticipantIds(String currentUid) async {
    return [currentUid];
  }

  Future<void> _saveTask() async {
    final user = FirebaseAuth.instance.currentUser;
    final title = _titleController.text.trim();

    if (user == null) {
      _showMessage('Please sign in first.');
      return;
    }

    if (title.isEmpty) {
      _showMessage('Please enter task title.');
      return;
    }

    if (_selectedDate == null) {
      _showMessage('Please select date.');
      return;
    }

    if (_selectedTime == null) {
      _showMessage('Please select time.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final participantIds = await _loadParticipantIds(user.uid);
      final startTime = _buildStartDateTime();
      final endTime = startTime.add(const Duration(hours: 1));
      final now = Timestamp.now();

      await FirebaseFirestore.instance.collection('events').add({
        'title': title,
        'description': _notesController.text.trim(),
        'eventType': _selectedEventType(),
        'familyId': '',
        'isAllDay': false,
        'location': '',
        'participantIds': participantIds,
        'reminderMinutes': _reminderEnabled ? 15 : 0,
        'repeatType': 'none',
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'status': 'active',
        'createdBy': user.uid,
        'createdAt': now,
      });

      if (!mounted) return;
      _showMessage('Task saved!');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage('Failed to save task: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDFBF7), Color(0xFFFFF7E1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              width: 430,
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 18),
                          _buildTitleInput(),
                          const SizedBox(height: 20),
                          _buildCategoryChips(),
                          const SizedBox(height: 22),
                          _buildDateTimeCard(),
                          const SizedBox(height: 20),
                          _buildNotesSection(),
                          const SizedBox(height: 20),
                          _buildReminderCard(),
                          const SizedBox(height: 20),
                          _buildSaveButton(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: _primaryColor,
                ),
              ),
            ),
          ),
          const Text(
            'Add Task',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _primaryColor,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Task Title',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _labelColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Add task title',
              hintStyle: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_categories.length, (index) {
        final category = _categories[index];
        final selected = _selectedCategoryIndex == index;
        final color = category['color'] as Color;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
              });
            },
            child: Container(
              height: 40,
              margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.15) : _card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? color.withOpacity(0.25)
                      : const Color(0xFFE5E7EB),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: selected ? color : color.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category['label'] as String,
                    style: TextStyle(
                      color: selected ? color : const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDateTimeCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Column(
        children: [
          _buildDateTimeRow(
            icon: Icons.calendar_month,
            label: 'Date',
            value: _dateText(),
            onTap: _pickDate,
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFEDE6D3)),
          _buildDateTimeRow(
            icon: Icons.access_time,
            label: 'Time',
            value: _timeText(),
            onTap: _pickTime,
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: _accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.notes, size: 18, color: _labelColor),
            SizedBox(width: 8),
            Text(
              'NOTES',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _labelColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 120),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: TextField(
            controller: _notesController,
            maxLines: null,
            minLines: 4,
            decoration: const InputDecoration(
              hintText: 'Add some extra details here...',
              hintStyle: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
            ),
            style: const TextStyle(color: Color(0xFF334155), fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildReminderCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.notifications, color: _accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Reminders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '15 minutes before',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _reminderEnabled,
            activeColor: _accentColor,
            onChanged: (value) {
              setState(() {
                _reminderEnabled = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFDBA3C), Color(0xFFFFA800)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA9E22).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _isSaving ? null : _saveTask,
            child: Center(
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Task',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
