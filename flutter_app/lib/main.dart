import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
part 'core/api.dart';
part 'app/app.dart';
part 'screens/auth/entry_screen.dart';
part 'screens/auth/auth_screen.dart';
part 'models/module.dart';
part 'screens/shared/app_shell.dart';
part 'screens/shared/records_screen.dart';
part 'screens/shared/record_form.dart';
part 'screens/shared/profile_editor.dart';
part 'screens/shared/announcements_screen.dart';
part 'screens/shared/admin_announcements_screen.dart';


const navy = Color(0xFF123C69);
const ocean = Color(0xFF247BA0);
const pale = Color(0xFFD9F0FA);
const canvas = Color(0xFFF5F9FC);
const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3001/api',
);

void main() => runApp(const HomeLinkApp());

void toast(BuildContext context, String message) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
String err(Object e) => e.toString().replaceFirst('Exception: ', '');
