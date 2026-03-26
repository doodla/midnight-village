import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const small = BorderRadius.all(Radius.circular(4));
  static const medium = BorderRadius.all(Radius.circular(8)); // default
  static const large = BorderRadius.all(Radius.circular(12));
  static const xl = BorderRadius.all(Radius.circular(16));
  static const full = BorderRadius.all(Radius.circular(999));
}
