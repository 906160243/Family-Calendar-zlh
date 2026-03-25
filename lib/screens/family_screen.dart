import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';

class FamilyScreen extends StatefulWidget {
  final String familyId;
  final String familyName;

  const FamilyScreen({
    Key? key,
    required this.familyId,
    required this.familyName,
  }) : super(key: key);

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  static const bgColor = Color(0xFFFDFAF2);
  static const primaryColor = Color(0xFF5C4D33);
  static const accentColor = Color(0xFFE2B736);
  static const dangerColor = Color(0xFFD64545);

  late Future<List<Map<String, dynamic>>> _membersFuture;

  final TextEditingController _inviteEmailController = TextEditingController();

  bool _isInviting = false;
  bool _isProcessingAction = false;

  String? _currentUid;
  String _currentRole = 'member';

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _membersFuture = _loadFamilyMembers();
    _loadCurrentUserRole();
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    super.dispose();
  }

  Future<void> _refreshMembers() async {
    await _loadCurrentUserRole();
    final future = _loadFamilyMembers();
    setState(() {
      _membersFuture = future;
    });
    await future;
  }

  Future<void> _loadCurrentUserRole() async {
    if (_currentUid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyId)
        .collection('members')
        .doc(_currentUid)
        .get();

    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final role = (data['role'] ?? 'member').toString().trim();

    if (mounted) {
      setState(() {
        _currentRole = role.isEmpty ? 'member' : role;
      });
    }
  }

  Future<Map<String, dynamic>?> _findUserByUid(String userId) async {
    final firestore = FirebaseFirestore.instance;

    final directDoc = await firestore.collection('users').doc(userId).get();
    if (directDoc.exists) {
      return directDoc.data();
    }

    final query = await firestore
        .collection('users')
        .where('uid', isEqualTo: userId)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }

    return null;
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserDocByEmail(
      String email,
      ) async {
    final firestore = FirebaseFirestore.instance;
    final normalizedEmail = email.trim().toLowerCase();

    final query = await firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first;
    }

    return null;
  }

  Future<void> _inviteUserByEmail() async {
    if (_isInviting) return;

    final inputEmail = _inviteEmailController.text.trim().toLowerCase();

    if (inputEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    try {
      setState(() {
        _isInviting = true;
      });

      final firestore = FirebaseFirestore.instance;
      final familyRef = firestore.collection('families').doc(widget.familyId);
      final familyDoc = await familyRef.get();

      if (!familyDoc.exists) {
        throw Exception('Family does not exist');
      }

      final familyData = familyDoc.data() ?? {};
      final familyName =
      (familyData['familyName'] ?? widget.familyName).toString();
      final familyPhotoURL = (familyData['photoURL'] ?? '').toString();

      final invitedUserDoc = await _findUserDocByEmail(inputEmail);

      if (invitedUserDoc == null) {
        throw Exception('No user found with this email');
      }

      final invitedUid = invitedUserDoc.id;
      final invitedUserData = invitedUserDoc.data();

      final nickname = (invitedUserData['fullName'] ??
          invitedUserData['name'] ??
          invitedUserData['displayName'] ??
          invitedUserData['nickname'] ??
          inputEmail)
          .toString();

      final existingMemberDoc =
      await familyRef.collection('members').doc(invitedUid).get();

      if (existingMemberDoc.exists) {
        throw Exception('This user is already in the family');
      }

      final userFamilyRef = firestore
          .collection('users')
          .doc(invitedUid)
          .collection('families')
          .doc(widget.familyId);

      final existingUserFamilyDoc = await userFamilyRef.get();
      if (existingUserFamilyDoc.exists) {
        throw Exception('This user already has this family in profile');
      }

      final now = Timestamp.now();
      final batch = firestore.batch();

      batch.set(userFamilyRef, {
        'familyId': widget.familyId,
        'familyName': familyName,
        'joinedAt': now,
        'photoURL': familyPhotoURL,
        'role': 'member',
      });

      batch.set(
        familyRef.collection('members').doc(invitedUid),
        {
          'uid': invitedUid,
          'nickname': nickname,
          'role': 'member',
          'familyRole': 'member',
          'status': 'active',
          'joinedAt': now,
        },
      );

      await batch.commit();

      _inviteEmailController.clear();
      await _refreshMembers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nickname has been added to the family')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }

  Future<void> _disbandFamily() async {
    if (_isProcessingAction) return;

    final confirmed = await _showConfirmDialog(
      title: 'Disband family?',
      message: 'This will remove the family for all members.',
      confirmText: 'Disband',
      confirmColor: dangerColor,
    );

    if (!confirmed) return;

    try {
      setState(() {
        _isProcessingAction = true;
      });

      final firestore = FirebaseFirestore.instance;
      final familyRef = firestore.collection('families').doc(widget.familyId);
      final membersSnapshot = await familyRef.collection('members').get();
      final batch = firestore.batch();

      for (final memberDoc in membersSnapshot.docs) {
        final memberUid = memberDoc.id;

        batch.delete(
          firestore
              .collection('users')
              .doc(memberUid)
              .collection('families')
              .doc(widget.familyId),
        );

        batch.delete(memberDoc.reference);
      }

      batch.delete(familyRef);

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family disbanded successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _removeMember(String targetUid, String targetName) async {
    if (_isProcessingAction) return;

    final confirmed = await _showConfirmDialog(
      title: 'Remove member?',
      message: 'Remove $targetName from this family?',
      confirmText: 'Remove',
      confirmColor: dangerColor,
    );

    if (!confirmed) return;

    try {
      setState(() {
        _isProcessingAction = true;
      });

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      batch.delete(
        firestore
            .collection('families')
            .doc(widget.familyId)
            .collection('members')
            .doc(targetUid),
      );

      batch.delete(
        firestore
            .collection('users')
            .doc(targetUid)
            .collection('families')
            .doc(widget.familyId),
      );

      await batch.commit();
      await _refreshMembers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$targetName removed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _leaveFamily() async {
    if (_isProcessingAction) return;

    final uid = _currentUid;
    if (uid == null) return;

    final confirmed = await _showConfirmDialog(
      title: 'Leave family?',
      message: 'You will leave this family.',
      confirmText: 'Leave',
      confirmColor: dangerColor,
    );

    if (!confirmed) return;

    try {
      setState(() {
        _isProcessingAction = true;
      });

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      batch.delete(
        firestore
            .collection('families')
            .doc(widget.familyId)
            .collection('members')
            .doc(uid),
      );

      batch.delete(
        firestore
            .collection('users')
            .doc(uid)
            .collection('families')
            .doc(widget.familyId),
      );

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You left the family')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                confirmText,
                style: TextStyle(
                  color: confirmColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<List<Map<String, dynamic>>> _loadFamilyMembers() async {
    final firestore = FirebaseFirestore.instance;

    final snapshot = await firestore
        .collection('families')
        .doc(widget.familyId)
        .collection('members')
        .get();

    final List<Map<String, dynamic>> members = [];

    for (final doc in snapshot.docs) {
      final memberData = doc.data();

      final String userId =
      (memberData['uid'] ?? memberData['userId'] ?? doc.id)
          .toString()
          .trim();

      if (userId.isEmpty) {
        continue;
      }

      final Map<String, dynamic>? userData = await _findUserByUid(userId);

      final String role = (memberData['role'] ?? 'member').toString().trim();

      final String fullName = (userData?['fullName'] ??
          userData?['name'] ??
          userData?['displayName'] ??
          memberData['nickname'] ??
          memberData['fullName'] ??
          memberData['name'] ??
          memberData['displayName'] ??
          'Unknown Member')
          .toString();

      final String photoURL = (userData?['photoURL'] ??
          userData?['photoUrl'] ??
          userData?['avatar'] ??
          memberData['photoURL'] ??
          memberData['photoUrl'] ??
          memberData['avatar'] ??
          '')
          .toString()
          .trim();

      members.add({
        'userId': userId,
        'name': fullName,
        'role': role.isEmpty ? 'member' : role,
        'badge': role.toLowerCase() == 'owner' ? 'Owner' : null,
        'photoURL': photoURL,
      });
    }

    return members;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshMembers,
                color: accentColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInviteSection(),
                        const SizedBox(height: 40),
                        _buildCommunicationSection(context),
                        const SizedBox(height: 40),
                        _buildExistingFamilySection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF3EEE0),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.arrow_back, size: 20, color: Colors.black54),
              ),
            ),
          ),
          Text(
            widget.familyName.isEmpty ? 'Family Member' : widget.familyName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildInviteSection() {
    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INVITE VIA EMAIL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primaryColor.withOpacity(0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEE0),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inviteEmailController,
                      enabled: !_isInviting,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'family.member@email.com',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: primaryColor.withOpacity(0.4),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isInviting
                        ? null
                        : () {
                      _inviteEmailController.clear();
                    },
                    child: const Icon(
                      Icons.clear,
                      size: 24,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE2B736), Color(0xFFF0C954)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE2B736).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isInviting ? null : _inviteUserByEmail,
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isInviting)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: primaryColor,
                          ),
                        )
                      else ...const [
                        Text(
                          'Send Invitation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.send, size: 14, color: primaryColor),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommunicationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Communication',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chat_bubble,
                      size: 20,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Family Group Chat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Connect with everyone instantly',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingFamilySection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Existing Family',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EEE0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${members.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.sort, size: 22, color: Colors.black54),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: accentColor),
                ),
              )
            else if (snapshot.hasError)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFF3EEE0)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Failed to load family members',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              )
            else if (members.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFF3EEE0)),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'No family members found.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _buildFamilyMemberCard(member);
                  },
                ),
          ],
        );
      },
    );
  }

  Widget _buildFamilyMemberCard(Map<String, dynamic> member) {
    final String photoURL = (member['photoURL'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3EEE0)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.2),
                width: 2,
              ),
              color: const Color(0xFFF3EEE0),
            ),
            child: ClipOval(
              child: photoURL.isNotEmpty
                  ? Image.network(
                photoURL,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Center(
                    child: Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.grey,
                    ),
                  );
                },
              )
                  : const Center(
                child: Icon(
                  Icons.person,
                  size: 32,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (member['name'] ?? 'Unknown Member').toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                Text(
                  (member['role'] ?? 'MEMBER').toString().toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          _buildMemberActionWidget(member),
        ],
      ),
    );
  }

  Widget _buildMemberActionWidget(Map<String, dynamic> member) {
    final String memberUid = (member['userId'] ?? '').toString().trim();
    final String memberName = (member['name'] ?? 'Member').toString();
    final bool isMe = memberUid == _currentUid;
    final bool isOwner = _currentRole.toLowerCase() == 'owner';

    if (isOwner && isMe) {
      return _buildActionButton(
        text: 'Disband',
        onTap: _isProcessingAction ? null : _disbandFamily,
      );
    }

    if (isOwner && !isMe) {
      return _buildActionButton(
        text: 'Remove',
        onTap: _isProcessingAction
            ? null
            : () => _removeMember(memberUid, memberName),
      );
    }

    if (!isOwner && isMe) {
      return _buildActionButton(
        text: 'Leave',
        onTap: _isProcessingAction ? null : _leaveFamily,
      );
    }

    if (member['badge'] != null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          member['badge'].toString().toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: accentColor,
            letterSpacing: 1,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(onTap == null ? 0.05 : 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: onTap == null ? primaryColor.withOpacity(0.35) : accentColor,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
    );
  }

  Widget _navItem(
      BuildContext context,
      IconData icon,
      String label, {
        bool selected = false,
        VoidCallback? onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
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