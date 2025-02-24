import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mosques.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE mosques (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');

        // ✅ إدخال بيانات مساجد مبدئية
        await db.insert('mosques', {'name': 'مسجد الفاتح'});
        await db.insert('mosques', {'name': 'مسجد النور'});
        await db.insert('mosques', {'name': 'مسجد التوحيد'});
        await db.insert('mosques', {'name': 'مسجد الإحسان'});
      },
    );
  }

  // ✅ إحضار جميع المساجد
  Future<List<Map<String, dynamic>>> getMosques() async {
    final db = await database;
    return await db.query('mosques', orderBy: 'name ASC');
  }
}
