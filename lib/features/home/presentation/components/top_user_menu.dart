import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class TopUserMenu extends ConsumerWidget {
  final String userName;
  final Color? backgroundColor;

  const TopUserMenu({super.key, required this.userName, this.backgroundColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final balance = ref.watch(orgCreditBalanceProvider);

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      onSelected: (value) async {
        if (value == 'buy_credits') {
          if (context.mounted) {
            context.go(AppRouter.buyCredits);
          }
        } else if (value == 'profile') {
          // Toggle the personal profile panel overlay
          ref.read(personalProfilePanelProvider.notifier).state = true;
        } else if (value == 'preferences') {
          if (context.mounted) {
            context.go(AppRouter.profile);
          }
        } else if (value == 'terms') {
          await launchUrl(Uri.parse(kTermsUrl));
        } else if (value == 'privacy') {
          await launchUrl(Uri.parse(kPrivacyUrl));
        } else if (value == 'report') {
          if (context.mounted) {
            await reportContent(
              context,
              subject: 'Report a problem in Zedu',
              details: 'Describe the person, message or problem:',
            );
          }
        } else if (value == 'logout') {
          await ref.read(authNotifierProvider.notifier).logout();
          if (context.mounted) {
            context.go(AppRouter.login);
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'AI Credits: $balance',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'buy_credits',
          child: Row(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Buy AI credits',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 20, color: colors.textPrimary),
              const SizedBox(width: 8),
              const Text('Profile'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'preferences',
          child: Row(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 20,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 8),
              const Text('Preferences'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 20, color: colors.textPrimary),
              const SizedBox(width: 8),
              const Text('Report a problem'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'terms',
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 20,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 8),
              const Text('Terms of Service'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'privacy',
          child: Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 20,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 8),
              const Text('Privacy Policy'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: colors.error),
              const SizedBox(width: 8),
              Text('Logout', style: TextStyle(color: colors.error)),
            ],
          ),
        ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.onPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'ZU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              userName,
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              color: colors.onPrimary.withValues(alpha: 0.7),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
