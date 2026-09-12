import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String _dbName = 'erp_database.db';
  static const int _dbVersion = 2;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Table: products
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        barcode TEXT NOT NULL,
        name TEXT NOT NULL,
        unit_price REAL NOT NULL
      )
    ''');

    // 2. Table: invoices
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE,
        invoice_number TEXT NOT NULL,
        invoice_date TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        exchange_rate REAL NOT NULL DEFAULT 1.0,
        tax_mode TEXT NOT NULL,
        tax_rate REAL NOT NULL DEFAULT 16.0,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        subtotal_amount REAL NOT NULL,
        tax_amount REAL NOT NULL,
        total_amount REAL NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. Table: invoice_items
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_invoice_id INTEGER NOT NULL,
        server_invoice_id INTEGER,
        product_id INTEGER,
        item_description TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        line_total REAL NOT NULL,
        FOREIGN KEY (local_invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    // 4. Table: deleted_server_invoices
    // تتبع IDs الفواتير المحذوفة محلياً لمنع إعادتها من السيرفر عند الجلب
    await db.execute('''
      CREATE TABLE deleted_server_invoices (
        server_id INTEGER PRIMARY KEY
      )
    ''');

    // Indexes for fast lookup
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_invoices_synced ON invoices(is_synced)');
  }

  // Migrate existing databases to version 2
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deleted_server_invoices (
          server_id INTEGER PRIMARY KEY
        )
      ''');
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
