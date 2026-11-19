import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'host_change.dart';

/// The table no longer exists (its last member left): says so in a plain line
/// and returns to the home screen. Safe to call from a listener; the line
/// outlives the screen it was raised on.
void showTableClosedAndGoHome(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text(kTableClosedMessage)));
  context.go('/');
}
