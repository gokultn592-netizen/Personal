import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth_service.dart';
import '../main_shell.dart';
import '../../widgets/nx_field.dart';
import 'pending_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  final _nameCtrl = TextEditingController();
  final _regNoCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedBranch = kDepartments.first;
  String _selectedYear = kAcademicYears.first;

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  static String _yearSuffix(String y) {
    if (y == '1') return 'st';
    if (y == '2') return 'nd';
    if (y == '3') return 'rd';
    return 'th';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regNoCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _busy = true;
    });

    final name = _nameCtrl.text.trim();
    final regNo = _regNoCtrl.text.trim().toUpperCase();

    try {
      final error = await _auth.registerCandidate(
        name: name,
        regNo: regNo,
        branch: _selectedBranch,
        year: _selectedYear,
        phoneNo: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      if (error != null) {
        setState(() => _error = error);
        return;
      }

      // A member already approved in the Nexus community is admitted straight
      // away — showing them the "waiting for an admin" screen would be wrong.
      final autoApproved = await _auth.wasApprovedViaNexus();
      if (!mounted) return;

      if (autoApproved) {
        showNxSnack(context, 'Verified via your Nexus membership.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const MainShell()),
          (route) => false,
        );
        return;
      }

      showNxSnack(context, 'Submitted. An admin must stamp your identity.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PendingScreen(name: name, regNo: regNo),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _uppercaseRegNo(String value) {
    final upper = value.toUpperCase();
    if (value != upper) {
      _regNoCtrl.value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
    final detected = inferBranchFromRegNo(upper);
    if (detected != null && kDepartments.contains(detected) && _selectedBranch != detected) {
      setState(() => _selectedBranch = detected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraTheme.scaffold,
      appBar: AppBar(title: const Text('Request access')),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: alphaOf(NexoraTheme.primary, 0.14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: alphaOf(NexoraTheme.primary, 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 26,
                            color: NexoraTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create your identity',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: NexoraTheme.textPrimary,
                                  letterSpacing: -0.4,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Admin approval is required before reading or posting.',
                                style: TextStyle(
                                  color: NexoraTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (_error != null) ...[
                      _errorBox(_error!),
                      const SizedBox(height: 16),
                    ],
                    NxField(
                      controller: _nameCtrl,
                      label: 'Full name',
                      hint: 'As printed on your ID card',
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: NexoraTheme.textSecondary,
                      ),
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.isEmpty) return 'Name is required';
                        if (name.length < 3) return 'Enter your full name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    NxField(
                      controller: _regNoCtrl,
                      label: 'Registration number',
                      hint: '25MID0051',
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: _uppercaseRegNo,
                      prefixIcon: const Icon(
                        Icons.badge_outlined,
                        size: 20,
                        color: NexoraTheme.textSecondary,
                      ),
                      validator: (value) {
                        final regNo = (value ?? '').trim().toUpperCase();
                        if (regNo.isEmpty) return 'Registration number is required';
                        final valid =
                            RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(regNo);
                        return valid
                            ? null
                            : 'Letters and numbers only (4-20 characters)';
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Branch Dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Branch / Program',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: NexoraTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedBranch,
                                dropdownColor: NexoraTheme.card,
                                isExpanded: true,
                                style: GoogleFonts.poppins(
                                  color: NexoraTheme.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: NexoraTheme.card,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: NexoraTheme.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: NexoraTheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: kDepartments
                                    .map(
                                      (b) => DropdownMenuItem(
                                        value: b,
                                        child: Text(
                                          formatBranchName(b, full: true),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedBranch = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Year of Study Dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Year of Study',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: NexoraTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedYear,
                                dropdownColor: NexoraTheme.card,
                                isExpanded: true,
                                style: GoogleFonts.poppins(
                                  color: NexoraTheme.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: NexoraTheme.card,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: NexoraTheme.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: NexoraTheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: kAcademicYears
                                    .map(
                                      (y) => DropdownMenuItem(
                                        value: y,
                                        child: Text('$y${_yearSuffix(y)} Year'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedYear = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    NxField(
                      controller: _phoneCtrl,
                      label: 'Phone number',
                      hint: '9876543210',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        size: 20,
                        color: NexoraTheme.textSecondary,
                      ),
                      validator: (value) {
                        final digits =
                            (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.isEmpty) return 'Phone number is required';
                        if (digits.length < 10 || digits.length > 15) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    NxField(
                      controller: _emailCtrl,
                      label: 'Email address',
                      hint: 'you@student.edu',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(
                        Icons.alternate_email_rounded,
                        size: 20,
                        color: NexoraTheme.textSecondary,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Email is required';
                        final valid =
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                        return valid ? null : 'Enter a valid email address';
                      },
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 14),
                    NxField(
                      controller: _passwordCtrl,
                      label: 'Password',
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: NexoraTheme.textSecondary,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: NexoraTheme.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.isEmpty) return 'Password is required';
                        if (password.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit for approval'),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Your request is queued under your registration number. Access is granted once an admin approves it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: NexoraTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacementNamed('/login');
                        }
                      },
                      child: const Text(
                        'Already have an account? Sign in',
                        style: TextStyle(
                          color: NexoraTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String message) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: alphaOf(NexoraTheme.error, 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: alphaOf(NexoraTheme.error, 0.4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: NexoraTheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: NexoraTheme.error,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
