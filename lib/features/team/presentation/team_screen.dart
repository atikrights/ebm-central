import 'package:flutter/material.dart';
import 'user_manager_screen.dart';

class TeamScreen extends StatelessWidget {
  final int view;
  const TeamScreen({super.key, this.view = 0});

  @override
  Widget build(BuildContext context) {
    return UserManagerScreen(initialView: view);
  }
}
