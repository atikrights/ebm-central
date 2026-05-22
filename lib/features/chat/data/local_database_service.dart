import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' if (dart.library.html) 'package:frontend/core/utils/io_stub.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  static Database? _database;

  factory LocalDatabaseService() => _instance;

  LocalDatabaseService._internal();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb) return null;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path = join(await getDatabasesPath(), 'ebm_chat_v2.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // 1. Messages Table
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY,
        client_id TEXT,
        sender_id INTEGER,
        receiver_id INTEGER,
        message TEXT,
        message_type TEXT,
        status TEXT,
        created_at TEXT,
        delivered_at TEXT,
        read_at TEXT,
        file_path TEXT,
        file_name TEXT,
        is_mine INTEGER
      )
    ''');

    // 2. Conversations/Sessions Table
    await db.execute('''
      CREATE TABLE sessions (
        partner_id TEXT PRIMARY KEY,
        partner_name TEXT,
        last_message TEXT,
        last_message_at TEXT,
        unread_count INTEGER,
        type TEXT
      )
    ''');
  }

  // --- Helpers ---
  
  Future<void> saveMessage(Map<String, dynamic> msg) async {
    if (kIsWeb) return;
    final db = await database;
    if (db == null) return;
    await db.insert('messages', msg, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Update session too
    await updateSessionFromMessage(msg);
  }

  Future<void> updateSessionFromMessage(Map<String, dynamic> msg) async {
    if (kIsWeb) return;
    final db = await database;
    if (db == null) return;
    final partnerId = msg['is_mine'] == 1 ? msg['receiver_id'].toString() : msg['sender_id'].toString();
    
    await db.insert('sessions', {
      'partner_id': partnerId,
      'last_message': msg['message'],
      'last_message_at': msg['created_at'],
      'unread_count': msg['is_mine'] == 1 ? 0 : 1, // Logic to increment unread if not mine
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMessages(String partnerId) async {
    if (kIsWeb) return [];
    final db = await database;
    if (db == null) return [];
    return await db.query('messages', 
      where: 'sender_id = ? OR receiver_id = ?', 
      whereArgs: [partnerId, partnerId],
      orderBy: 'id ASC'
    );
  }
}
