import 'package:flutter/material.dart';
import 'auth_config.dart';
import 'auth_api_client.dart';
import 'app_auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  static const _rust = Color(0xFFA4542D);
  static const _forest = Color(0xFF21463C);
  static const _ink = Color(0xFF282C28);

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() { _error = null; _busy = true; });
    try {
      await AppAuthController.instance.login(
        username: _username.text,
        password: _password.text,
      );
    } on AuthApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'ورود ناموفق بود. دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: _rust, size: 21),
    filled: true,
    fillColor: const Color(0xFFF8F5F1),
    contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Color(0xFFE8DED6))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Color(0xFFE8DED6))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: _rust, width: 1.6)),
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFAF4),
        body: SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 114, height: 114,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFF0E6DD)),
                  boxShadow: const [BoxShadow(color: Color(0x159A542D), blurRadius: 24, offset: Offset(0, 10))]),
                child: Image.asset('assets/images/company_logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 20),
              const Text('مدیریت هوشمند گله', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _forest)),
              const SizedBox(height: 7),
              const Text('ورود به سامانه شترها',
                style: TextStyle(color: Color(0xFF877B72), fontSize: 14)),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 21),
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [BoxShadow(color: Color(0x0D674028), blurRadius: 30, offset: Offset(0, 9))]),
                child: Form(key: _formKey, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('حساب کاربری', style: TextStyle(color: _ink,
                      fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration('نام کاربری', Icons.person_outline_rounded),
                      validator: (v) => v == null || v.trim().isEmpty ? 'نام کاربری را وارد کنید' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _login(),
                      decoration: _fieldDecoration('رمز عبور', Icons.lock_outline_rounded).copyWith(
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF98847A)),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'رمز عبور را وارد کنید' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Color(0xFFBA3939), fontSize: 12)),
                    ],
                    const SizedBox(height: 17),
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: _rust, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Text('ورود به حساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    if (AuthConfig.demoAllowed) ...[
                      const SizedBox(height: 13),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () async {
                          try {
                            await AppAuthController.instance.enterDemo();
                          } catch (_) {
                            if (mounted) setState(() => _error = 'ورود آزمایشی انجام نشد.');
                          }
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                        label: const Text('ورود آزمایشی بدون API'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _forest,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFC7D8D0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ],
                )),
              ),
              const SizedBox(height: 14),
              if (!AuthConfig.hasApi)
                const Text('اتصال به سرور هنوز تنظیم نشده است.',
                    style: TextStyle(color: Color(0xFF8F8178), fontSize: 12)),
              if (AppAuthController.instance.startupMessage != null)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text(AppAuthController.instance.startupMessage!,
                    style: const TextStyle(color: Color(0xFF9C5134), fontSize: 12),
                    textAlign: TextAlign.center)),
            ]),
          ),
        ))),
      ),
    );
  }
}
