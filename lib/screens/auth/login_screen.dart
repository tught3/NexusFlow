import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../flow_core/supabase_client/auth_service.dart';

const Color _kBackground = Color(0xFFF8FAFC);
const Color _kTextPrimary = Color(0xFF16213E);
const Color _kTextSecondary = Color(0xFF64748B);
const Color _kPrimary = Color(0xFF2563EB);
const Color _kBorder = Color(0xFFE2E8F0);

const TextStyle _kLabelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: _kTextPrimary,
);

final RegExp _emailRegex = RegExp(
  r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();
  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일을 입력해 주세요.';
    if (!_emailRegex.hasMatch(email)) return '올바른 이메일 형식이 아니에요.';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '비밀번호를 입력해 주세요.';
    if (password.length < 6) return '비밀번호는 6자 이상이어야 해요.';
    return null;
  }

  String _friendlyError(Object error) {
    final message =
        error is AuthException ? error.message : error.toString();
    if (message.contains('Invalid login credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않아요.';
    }
    if (message.contains('User already registered')) {
      return '이미 가입된 이메일이에요. 로그인해 주세요.';
    }
    if (message.contains('at least 6 characters')) {
      return '비밀번호를 6자 이상으로 입력해 주세요.';
    }
    if (message.contains('rate limit') || message.contains('Too many')) {
      return '요청이 많아요. 잠시 후 다시 시도해 주세요.';
    }
    return message;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      // AuthService는 빌드 타임이 아닌 핸들러 내에서 생성 —
      // Supabase 미초기화 상태(위젯 테스트)에서 build가 크래시하지 않게 한다.
      final authService = AuthService();
      if (_isSignUpMode) {
        final response = await authService.signUpWithEmail(
          email: _emailController.text,
          password: _pwController.text,
        );
        if (!mounted) return;
        if (response.session == null) {
          _showSnackBar('이메일을 확인해 주세요. 인증 후 로그인할 수 있어요.');
        }
        // 세션이 있으면 app.dart의 redirect가 자동으로 다음 화면으로 보낸다.
      } else {
        await authService.signInWithEmail(
          email: _emailController.text,
          password: _pwController.text,
        );
      }
    } catch (error) {
      if (mounted) _showSnackBar(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      _showSnackBar('이메일을 먼저 입력해 주세요.');
      return;
    }
    try {
      await AuthService().sendPasswordResetEmail(email);
      if (mounted) {
        _showSnackBar('비밀번호 재설정 메일을 보냈어요. 메일함을 확인해 주세요.');
      }
    } catch (error) {
      if (mounted) _showSnackBar(_friendlyError(error));
    }
  }

  Future<void> _signInWithOAuth(PlanFlowOAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      final launched = await AuthService().signInWithOAuth(provider);
      if (!mounted) return;
      if (!launched) {
        _showSnackBar('브라우저를 열 수 없어요. 잠시 후 다시 시도해 주세요.');
      }
    } catch (error) {
      if (mounted) _showSnackBar(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LogoSection(),
                    const SizedBox(height: 32),
                    _buildEmailField(),
                    const SizedBox(height: 14),
                    _buildPasswordField(),
                    const SizedBox(height: 20),
                    _buildSubmitButton(),
                    const SizedBox(height: 8),
                    _buildModeToggle(),
                    const SizedBox(height: 24),
                    _buildDivider(),
                    const SizedBox(height: 24),
                    _buildOAuthButtons(),
                    const SizedBox(height: 28),
                    Text(
                      '로그인하면 이용약관과 개인정보처리방침에 동의하는 것으로 간주돼요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextSecondary,
                        height: 1.5,
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

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('이메일', style: _kLabelStyle),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: _inputDecoration(hintText: 'name@example.com'),
          validator: _validateEmail,
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('비밀번호', style: _kLabelStyle),
            TextButton(
              onPressed: _isLoading ? null : _sendPasswordReset,
              style: TextButton.styleFrom(
                foregroundColor: _kPrimary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('비밀번호 찾기'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _pwController,
          enabled: !_isLoading,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
          decoration: _inputDecoration(
            hintText: '6자 이상',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: _kTextSecondary,
              ),
            ),
          ),
          validator: _validatePassword,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isSignUpMode ? '회원가입' : '로그인',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
    );
  }

  Widget _buildModeToggle() {
    return TextButton(
      onPressed: _isLoading
          ? null
          : () => setState(() => _isSignUpMode = !_isSignUpMode),
      child: Text(
        _isSignUpMode ? '이미 계정이 있으신가요? 로그인' : '계정이 없으신가요? 회원가입',
        style: const TextStyle(fontSize: 13, color: _kTextSecondary),
      ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: _kBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는',
            style: TextStyle(fontSize: 12, color: _kTextSecondary),
          ),
        ),
        Expanded(child: Divider(color: _kBorder)),
      ],
    );
  }

  Widget _buildOAuthButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _oauthButton(
          label: 'Google로 시작하기',
          initial: 'G',
          initialColor: const Color(0xFF4285F4),
          initialTextColor: Colors.white,
          onPressed: () =>
              _signInWithOAuth(PlanFlowOAuthProvider.google),
        ),
        const SizedBox(height: 10),
        _oauthButton(
          label: 'Kakao로 시작하기',
          initial: 'K',
          initialColor: const Color(0xFFFEE500),
          initialTextColor: const Color(0xFF1F1F1F),
          onPressed: () =>
              _signInWithOAuth(PlanFlowOAuthProvider.kakao),
        ),
        const SizedBox(height: 10),
        _oauthButton(
          label: 'Naver로 시작하기',
          initial: 'N',
          initialColor: const Color(0xFF03C75A),
          initialTextColor: Colors.white,
          onPressed: () =>
              _signInWithOAuth(PlanFlowOAuthProvider.naver),
        ),
      ],
    );
  }

  Widget _oauthButton({
    required String label,
    required String initial,
    required Color initialColor,
    required Color initialTextColor,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: _kBorder),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: _kTextPrimary,
      ),
      icon: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: initialColor,
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: initialTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText, Widget? suffixIcon}) {
    final outline = BorderSide(color: _kBorder);
    final focused = BorderSide(color: _kPrimary, width: 1.4);
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: outline,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: focused,
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _kPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 16),
        const Text(
          'NexusFlow',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _kTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '말했더니 알아서 정리됨',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: _kTextSecondary),
        ),
      ],
    );
  }
}
