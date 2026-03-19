import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_task_screen.dart';

class MemoDetailScreen extends StatefulWidget {
  final String memoId;
  final String title;
  final String body;
  final bool isCreating;

  const MemoDetailScreen({
    super.key,
    this.memoId = '',
    this.title = '',
    this.body = '',
    this.isCreating = false,
  });

  @override
  State<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends State<MemoDetailScreen> {
  static const _background = Color(0xFFF8F7F6);
  static const _primaryColor = Color(0xFF0F172A);
  static const _accentColor = Color(0xFFFAC638);
  static const _cardBorder = Color.fromRGBO(250, 198, 56, 0.05);
  static const _bodyText = Color(0xFF334155);

  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  late String _originalTitle;
  late String _originalBody;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _isAnalyzingTask = false;

  bool get _hasChanges {
    return _titleController.text.trim() != _originalTitle.trim() ||
        _bodyController.text.trim() != _originalBody.trim();
  }

  @override
  void initState() {
    super.initState();
    _originalTitle = widget.title;
    _originalBody = widget.body;
    _isEditing = widget.isCreating;
    _titleController = TextEditingController(text: widget.title)
      ..addListener(_handleFieldChanged);
    _bodyController = TextEditingController(text: widget.body)
      ..addListener(_handleFieldChanged);
  }

  void _handleFieldChanged() {
    if (!mounted || !_isEditing) {
      return;
    }
    setState(() {});
  }

  Future<void> _saveMemo() async {
    final user = FirebaseAuth.instance.currentUser;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (user == null) {
      _showMessage('Please sign in to save your memo.');
      return;
    }

    if (title.isEmpty && body.isEmpty) {
      _showMessage('Please enter your memo first.');
      return;
    }

    final effectiveTitle = title.isNotEmpty ? title : _fallbackTitle(body);

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isCreating) {
        await FirebaseFirestore.instance.collection('memos').add({
          'userId': user.uid,
          'title': effectiveTitle,
          'body': body,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) {
          return;
        }

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Memo saved.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }

      if (widget.memoId.isEmpty) {
        throw StateError('Missing memo id.');
      }

      await FirebaseFirestore.instance
          .collection('memos')
          .doc(widget.memoId)
          .update({
            'title': effectiveTitle,
            'body': body,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _originalTitle = effectiveTitle;
      _originalBody = body;

      if (!mounted) {
        return;
      }

      setState(() {
        _isEditing = false;
      });
      _showMessage('Memo updated.');
    } catch (_) {
      _showMessage('Failed to save memo. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    _titleController.text = _originalTitle;
    _bodyController.text = _originalBody;
    setState(() {
      _isEditing = false;
    });
  }

  String _fallbackTitle(String body) {
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _analyzeMemoAndOpenTask() async {
    final memoTitle = _originalTitle.trim();
    final memoBody = _originalBody.trim();

    if (memoTitle.isEmpty && memoBody.isEmpty) {
      _showMessage('This memo is empty.');
      return;
    }

    setState(() {
      _isAnalyzingTask = true;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'australia-southeast1',
      ).httpsCallable('analyzeMemoToTask');

      final result = await callable.call(<String, dynamic>{
        'title': memoTitle,
        'body': memoBody,
        'timezone': DateTime.now().timeZoneName,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final draft = _MemoTaskDraft.fromMap(data);

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddTaskScreen(
            initialTitle: draft.title.isNotEmpty ? draft.title : memoTitle,
            initialNotes: draft.notes.isNotEmpty ? draft.notes : memoBody,
            initialDate: draft.date,
            initialTime: draft.time,
            initialCategory: draft.category,
            initialReminderEnabled: draft.reminderEnabled,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      _showMessage(_mapFunctionError(error));
    } catch (_) {
      _showMessage('Failed to analyze memo. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingTask = false;
        });
      }
    }
  }

  String _mapFunctionError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please sign in to continue.';
      case 'invalid-argument':
        return 'This memo does not have enough content to analyze.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a few seconds.';
      default:
        return error.message ?? 'AI analysis failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    _bodyController
      ..removeListener(_handleFieldChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: Container(
            width: 430,
            constraints: const BoxConstraints(maxWidth: 430),
            height: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      const SizedBox(height: 89),
                      Expanded(child: _buildContent()),
                      SizedBox(height: widget.isCreating ? 32 : 112),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildAppBar(context),
                ),
                if (!widget.isCreating)
                  Positioned(
                    left: 46,
                    right: 46,
                    bottom: 20,
                    child: _buildAddTaskButton(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final actionLabel = widget.isCreating
        ? 'Save'
        : _isEditing
        ? (_hasChanges ? 'Save' : 'Edit')
        : 'Edit';

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          height: 89,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F5).withValues(alpha: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  if (_isEditing && !widget.isCreating) {
                    _cancelEditing();
                    return;
                  }
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEE0),
                    borderRadius: BorderRadius.circular(999),
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
              Expanded(
                child: Center(
                  child: Text(
                    widget.isCreating ? 'New Memo' : 'Memo Detail',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                      letterSpacing: -0.45,
                    ),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _isSaving
                    ? null
                    : () {
                        if (widget.isCreating) {
                          _saveMemo();
                          return;
                        }

                        if (!_isEditing) {
                          _startEditing();
                          return;
                        }

                        if (_hasChanges) {
                          _saveMemo();
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _accentColor,
                          ),
                        )
                      : Text(
                          actionLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _accentColor,
                            letterSpacing: 0.35,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        children: [
          const SizedBox(height: 39),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFAC638).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(25, 21, 25, 25),
            child: _isEditing ? _buildEditableBody() : _buildReadOnlyBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'Memo title',
            border: InputBorder.none,
            isCollapsed: true,
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _primaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bodyController,
          maxLines: 14,
          minLines: 10,
          decoration: const InputDecoration(
            hintText: 'Write your memo here...',
            border: InputBorder.none,
            isCollapsed: true,
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: _bodyText,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _originalTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _primaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _originalBody,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: _bodyText,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildAddTaskButton(BuildContext context) {
    return GestureDetector(
      onTap: _isAnalyzingTask ? null : _analyzeMemoAndOpenTask,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFAC638), Color(0xFFF59E0B)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFAC638).withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isAnalyzingTask
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Add Task',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _MemoTaskDraft {
  const _MemoTaskDraft({
    required this.title,
    required this.notes,
    required this.category,
    required this.date,
    required this.time,
    required this.reminderEnabled,
  });

  final String title;
  final String notes;
  final String? category;
  final DateTime? date;
  final TimeOfDay? time;
  final bool reminderEnabled;

  factory _MemoTaskDraft.fromMap(Map<String, dynamic> map) {
    final date = _parseDate(map['dateISO'] as String?);
    final time = _parseTime(map['time24h'] as String?);

    return _MemoTaskDraft(
      title: (map['title'] as String? ?? '').trim(),
      notes: (map['notes'] as String? ?? '').trim(),
      category: (map['category'] as String?)?.trim(),
      date: date,
      time: time,
      reminderEnabled: map['reminderEnabled'] as bool? ?? true,
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.trim());
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parts = value.trim().split(':');
    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }
}
