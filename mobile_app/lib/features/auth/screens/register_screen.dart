import 'package:flutter/material.dart';

import '../services/registration_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  final RegistrationService _service = RegistrationService();

  bool _submitting = false;
  bool _acceptedNotice = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _service.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) {
      return 'Enter at least 2 characters.';
    }
    if (text.length > 120) {
      return 'Use 120 characters or fewer.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter your email address.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.length < 8) {
      return 'Use at least 8 characters.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(text)) {
      return 'Include at least one letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(text)) {
      return 'Include at least one number.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _register() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_acceptedNotice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please acknowledge the wellness-support notice.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _service.register(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(_emailController.text.trim().toLowerCase());
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Create account'),
        backgroundColor: const Color(0xFFF7F7FC),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, 12, 24, viewInsets.bottom + 32),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9E8FF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 34,
                      color: Color(0xFF6059E8),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Join MindPulse AI',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create an account to save check-ins, journals, '
                    'recovery progress, and personalized wellness guidance.',
                    style: TextStyle(
                      color: Color(0xFF686878),
                      fontSize: 16,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const <String>[AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.email],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_submitting,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText:
                          'At least 8 characters with a letter and number.',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(() {
                                  _hidePassword = !_hidePassword;
                                });
                              },
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmationController,
                    enabled: !_submitting,
                    obscureText: _hideConfirmation,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_submitting) {
                        _register();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        tooltip: _hideConfirmation
                            ? 'Show confirmation'
                            : 'Hide confirmation',
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(() {
                                  _hideConfirmation = !_hideConfirmation;
                                });
                              },
                        icon: Icon(
                          _hideConfirmation
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: _validateConfirmation,
                  ),
                  const SizedBox(height: 18),
                  Card(
                    color: const Color(0xFFF0EFFF),
                    child: CheckboxListTile(
                      value: _acceptedNotice,
                      enabled: !_submitting,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _acceptedNotice = value ?? false;
                        });
                      },
                      title: const Text(
                        'I understand MindPulse provides wellness support, '
                        'not medical diagnosis.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _register,
                      icon: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        _submitting ? 'Creating account...' : 'Create account',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    child: const Text('Already have an account? Log in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
