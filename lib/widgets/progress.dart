import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

Widget smallCircularProgressIndicator({Color? color}) {
  return SizedBox(
    width: 12,
    height: 12,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}

Widget mdCircularProgressIndicator({Color? color}) {
  return SizedBox(
    width: 24,
    height: 24,
    child: CircularProgressIndicator(strokeWidth: 3, color: color),
  );
}
