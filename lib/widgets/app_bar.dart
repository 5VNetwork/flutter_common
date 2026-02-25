import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

AppBar adaptiveClosableAppBar(BuildContext context, {required String title}) {
  return AppBar(
    title: Text(title),
    automaticallyImplyLeading: false,
    leading: Platform.isMacOS
        ? null
        : IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.arrow_back_rounded),
          ),
    actions: !Platform.isMacOS
        ? null
        : [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.close_rounded),
              ),
            ),
          ],
  );
}
