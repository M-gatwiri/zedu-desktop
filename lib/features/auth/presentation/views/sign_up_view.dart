import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SignUpView extends ConsumerStatefulWidget {
  const SignUpView({super.key});

  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  static final _termsUrl = Uri.parse(kTermsUrl);
  static final _privacyUrl = Uri.parse(kPrivacyUrl);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Google may sign in an account that already exists, so the success toast
  // must not claim a new account was created.
  bool _signingUpWithGoogle = false;
  late final _loginLink = TapGestureRecognizer()
    ..onTap = () => context.go(AppRouter.login);
  late final _termsLink = TapGestureRecognizer()
    ..onTap = () => launchUrl(_termsUrl);
  late final _privacyLink = TapGestureRecognizer()
    ..onTap = () => launchUrl(_privacyUrl);

  @override
  void dispose() {
    _loginLink.dispose();
    _termsLink.dispose();
    _privacyLink.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onCreateAccountPressed() async {
    if (!_formKey.currentState!.validate()) return;
    _signingUpWithGoogle = false;

    ref
        .read(authNotifierProvider.notifier)
        .signUp(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  void _onGooglePressed() {
    if (ref.read(authNotifierProvider).isLoading) return;
    _signingUpWithGoogle = true;
    ref.read(authNotifierProvider.notifier).loginWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        AppToastService.show(
          context,
          type: AppToastType.success,
          message: _signingUpWithGoogle
              ? 'Signed in with Google!'
              : 'Account created successfully!',
        );
        context.go(AppRouter.home);
      }
      if (next.error != null && previous?.error != next.error) {
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: next.error!,
        );
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    if (authState.status == AuthStatus.unknown) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: context.colors.background,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/pngs/zedu_logo.png', width: 83, height: 31),
              Text.rich(
                TextSpan(
                  text: 'Already have an account? ',
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.colors.textPrimary,
                    fontFamily: FontFamily.roboto,
                  ),
                  children: [
                    TextSpan(
                      text: 'Sign in',
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: context.colors.primary,
                        fontFamily: FontFamily.roboto,
                      ),
                      recognizer: _loginLink,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                context.gapV(80),
                Text.rich(
                  TextSpan(
                    text: 'Stay Focused While ',
                    style: context.textTheme.headlineMedium?.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(
                        text: 'Zedu Handles The\nHustle',
                        style: context.textTheme.headlineMedium?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                context.gapV(48),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'Enter your username',
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Username is required';
                          }
                          return null;
                        },
                      ),
                      context.gapV(16),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email address',
                        hint: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validators.validateEmail(context, value),
                      ),
                      context.gapV(16),
                      AppTextField(
                        isPassword: true,
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Password',
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value != null &&
                              Validators.hasPasswordEdgeSpace(value)) {
                            return Validators.passwordEdgeSpaceMessage;
                          }
                          if (value == null || value.length < 8) {
                            return 'Password must be at least 8 characters long';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                context.gapV(24),
                AppButton(
                  label: 'Create Account',
                  loading: authState.isLoading,
                  onPressed: _onCreateAccountPressed,
                ),
                if (kSocialSignInEnabled) ...[
                  context.gapV(32),
                  Padding(
                    padding: context.symmetric(horizontal: 100, vertical: 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: context.colors.divider,
                            height: 0.67,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: context.colors.divider,
                            height: 0.67,
                          ),
                        ),
                      ],
                    ),
                  ),
                  context.gapV(32),
                  SocialAuthButton(
                    icon: 'assets/svgs/google_logo.svg',
                    label: 'Sign up with Google',
                    loading: authState.isLoading,
                    onPressed: _onGooglePressed,
                  ),
                  context.gapV(12),
                  SocialAuthButton(
                    icon: 'assets/svgs/apple_logo.svg',
                    label: 'Sign up with Apple',
                    onPressed: () => AppToastService.show(
                      context,
                      type: AppToastType.info,
                      message: 'Apple sign up is not available yet.',
                    ),
                  ),
                ],
                context.gapV(32),
                Text.rich(
                  TextSpan(
                    text: 'By signing up, you agree to our ',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms of Service',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.primary,
                        ),
                        recognizer: _termsLink,
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.primary,
                        ),
                        recognizer: _privacyLink,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                context.gapV(48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
