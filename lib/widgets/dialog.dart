import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_common/l10n/app_localizations.dart';

void showAlertDialog(BuildContext ctx, String text) {
  showDialog(
    context: ctx,
    builder: (context) => AlertDialog(title: Text(text)),
  );
}

void areYouSureDialog({
  required BuildContext ctx,
  required Widget title,
  Widget? content,
  required VoidCallback onYes,
  required VoidCallback onNo,
}) {
  showDialog(
    context: ctx,
    builder: (context) => AlertDialog(
      title: title,
      content: content,
      actions: [
        FilledButton(
          onPressed: onNo,
          child: Text(AppLocalizations.of(context)!.no),
        ),
        FilledButton(
          onPressed: onYes,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
          child: Text(
            AppLocalizations.of(context)!.yes,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
      ],
    ),
  );
}
