import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics_compat.dart';

Widget getCountryIcon(
  String countryCode, {
  double height = 24,
  double width = 24,
}) {
  return SvgPicture(
    height: height,
    width: width,
    AssetBytesLoader('assets/icons/flags/${countryCode.toLowerCase()}.svg.vec'),
  );
}
