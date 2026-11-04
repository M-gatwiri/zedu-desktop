import 'package:zedu/core/core.dart';

/// Opens the user's mail app with a report addressed to [kReportEmail].
///
/// Store policy 11.12 asks chat products to let users report harmful content
/// from inside the app. Until the backend has a report endpoint, reports go to
/// the support inbox by email.
Future<void> reportContent(
  BuildContext context, {
  required String subject,
  required String details,
}) async {
  final body =
      '$details\n\nWhy are you reporting this?\n\n'
      '(Sent from Zedu for Desktop)';
  final uri = Uri.parse(
    'mailto:$kReportEmail'
    '?subject=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
  final opened = await launchUrl(uri);
  if (!opened && context.mounted) {
    AppToastService.show(
      context,
      type: AppToastType.info,
      message: 'No email app found. Send your report to $kReportEmail.',
    );
  }
}

/// Wraps a message from someone else with a "Report message" action, shown on
/// hover, right-click or long-press.
class ReportMessageMenu extends StatefulWidget {
  const ReportMessageMenu({
    super.key,
    required this.senderName,
    required this.messageText,
    required this.child,
  });

  final String senderName;
  final String messageText;
  final Widget child;

  @override
  State<ReportMessageMenu> createState() => _ReportMessageMenuState();
}

class _ReportMessageMenuState extends State<ReportMessageMenu> {
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTap: () => _menuKey.currentState?.showButtonMenu(),
        onLongPress: () => _menuKey.currentState?.showButtonMenu(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(child: widget.child),
            Opacity(
              opacity: _hovered ? 1 : 0,
              child: PopupMenuButton<String>(
                key: _menuKey,
                tooltip: 'Message actions',
                icon: const Icon(Icons.more_horiz, size: 18),
                onSelected: (_) => reportContent(
                  context,
                  subject: 'Report: message from ${widget.senderName}',
                  details:
                      'Message from ${widget.senderName}:\n'
                      '"${widget.messageText}"',
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'report', child: Text('Report message')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
