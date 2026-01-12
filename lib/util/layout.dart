import 'package:flutter/material.dart';
import 'package:flutter_common/common.dart';

bool fullScreenLayout(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (desktopPlatform && width < 600) {
    return true;
  } else if (mobilePlatform && width < 840) {
    return true;
  }
  return false;
}
