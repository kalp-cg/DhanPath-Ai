import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dhanpath.db');
    return _database!;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 18,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<int> insertUnrecognizedSms(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert(
      'unrecognized_sms',
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future _createDB(Database db, int version) async {
    // Transactions table with unique constraint on sms_body
    await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      merchant_name TEXT NOT NULL,
      category TEXT NOT NULL,
      type TEXT NOT NULL,
      date TEXT NOT NULL,
      description TEXT,
      sms_body TEXT UNIQUE,
      bank_name TEXT,
      account_number TEXT,
      is_recurring INTEGER DEFAULT 0,
      is_deleted INTEGER DEFAULT 0,
      reference TEXT,
      balance REAL,
      credit_limit REAL,
      is_from_card INTEGER DEFAULT 0,
      currency TEXT DEFAULT 'INR',
      from_account TEXT,
      to_account TEXT,
      transaction_hash TEXT
    )
    ''');

    // Performance indexes on transactions
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_txn_date ON transactions(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_txn_type ON transactions(type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_txn_deleted ON transactions(is_deleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_txn_category ON transactions(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_txn_hash ON transactions(transaction_hash)',
    );

    // Holdings table removed for parity with Kotlin app

    // Account balances table
    await db.execute('''
    CREATE TABLE account_balances (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bank_name TEXT NOT NULL,
      account_number TEXT NOT NULL,
      balance REAL NOT NULL,
      timestamp TEXT NOT NULL,
      sms_body TEXT
    )
    ''');

    // Accounts table
    await db.execute('''
    CREATE TABLE accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bank_name TEXT NOT NULL,
      account_number TEXT NOT NULL,
      account_type TEXT NOT NULL,
      current_balance REAL,
      icon_name TEXT,
      is_active INTEGER DEFAULT 1
    )
    ''');

    // Subscriptions table
    await db.execute('''
    CREATE TABLE subscriptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      merchant_name TEXT NOT NULL,
      amount REAL NOT NULL,
      next_payment_date TEXT,
      state TEXT DEFAULT 'active',
      bank_name TEXT,
      umn TEXT,
      category TEXT,
      sms_body TEXT UNIQUE,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Budgets table
    await db.execute('''\r
    CREATE TABLE budgets (\r
      id INTEGER PRIMARY KEY AUTOINCREMENT,\r
      category TEXT NOT NULL,\r
      amount REAL NOT NULL,\r
      month TEXT NOT NULL,\r
      spent REAL DEFAULT 0,\r
      created_at TEXT NOT NULL,\r
      updated_at TEXT NOT NULL\r
    )\r
    ''');

    await db.execute('CREATE INDEX idx_budgets_month ON budgets(month)');
    await db.execute('CREATE INDEX idx_budgets_category ON budgets(category)');

    // Custom categories table
    await db.execute('''\r
    CREATE TABLE custom_categories (\r
      id INTEGER PRIMARY KEY AUTOINCREMENT,\r
      name TEXT NOT NULL UNIQUE,\r
      icon TEXT NOT NULL,\r
      color TEXT NOT NULL,\r
      type TEXT NOT NULL,\r
      is_default INTEGER DEFAULT 0,\r
      created_at TEXT NOT NULL\r
    )\r
    ''');

    // Rules table
    await db.execute('''\r
    CREATE TABLE rules (\r
      id INTEGER PRIMARY KEY AUTOINCREMENT,\r
      name TEXT NOT NULL,\r
      priority INTEGER DEFAULT 0,\r
      enabled INTEGER DEFAULT 1,\r
      conditions TEXT NOT NULL,\r
      actions TEXT NOT NULL,\r
      created_at TEXT NOT NULL,\r
      updated_at TEXT NOT NULL\r
    )\r
    ''');

    // Unrecognized SMS table
    await db.execute('''
    CREATE TABLE unrecognized_sms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sender TEXT NOT NULL,
      body TEXT NOT NULL,
      reason TEXT,
      received_at TEXT NOT NULL DEFAULT '',
      is_processed INTEGER DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT ''
    )
    ''');

    // IPO Mandates table
    await db.execute('''
    CREATE TABLE ipo_mandates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      company_name TEXT NOT NULL,
      amount REAL NOT NULL,
      status TEXT NOT NULL,
      applied_date TEXT NOT NULL,
      revoked_date TEXT,
      account_number TEXT,
      upi_id TEXT,
      bank_name TEXT NOT NULL,
      sms_body TEXT UNIQUE,
      is_deleted INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    await db.execute('CREATE INDEX idx_ipo_status ON ipo_mandates(status)');
    await db.execute('CREATE INDEX idx_ipo_date ON ipo_mandates(applied_date)');

    // Bill Reminders table
    await db.execute('''
    CREATE TABLE bill_reminders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_name TEXT NOT NULL,
      category TEXT NOT NULL,
      amount REAL NOT NULL,
      frequency TEXT NOT NULL,
      day_of_month INTEGER NOT NULL,
      next_due_date TEXT,
      last_paid_date TEXT,
      status TEXT NOT NULL,
      notes TEXT,
      is_active INTEGER DEFAULT 1,
      auto_detected INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');
    await db.execute('CREATE INDEX idx_bill_status ON bill_reminders(status)');
    await db.execute(
      'CREATE INDEX idx_bill_due ON bill_reminders(next_due_date)',
    );

    // EMI table
    await db.execute('''
    CREATE TABLE emis (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      lender_name TEXT NOT NULL,
      type TEXT NOT NULL,
      principal_amount REAL NOT NULL,
      emi_amount REAL NOT NULL,
      interest_rate REAL NOT NULL,
      tenure_months INTEGER NOT NULL,
      paid_months INTEGER DEFAULT 0,
      start_date TEXT NOT NULL,
      end_date TEXT,
      account_number TEXT,
      current_outstanding REAL,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');
    await db.execute('CREATE INDEX idx_emi_active ON emis(is_active)');

    // Expense Tags table
    await db.execute('''
    CREATE TABLE expense_tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      color TEXT NOT NULL,
      icon TEXT,
      is_tax_deductible INTEGER DEFAULT 0,
      is_business_expense INTEGER DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''');

    // Transaction Tags junction table
    await db.execute('''
    CREATE TABLE transaction_tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL,
      tag_id INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
      FOREIGN KEY (tag_id) REFERENCES expense_tags(id) ON DELETE CASCADE,
      UNIQUE(transaction_id, tag_id)
    )
    ''');
    await db.execute(
      'CREATE INDEX idx_transaction_tags ON transaction_tags(transaction_id)',
    );

    // Add receipt_path column to transactions
    await db.execute('ALTER TABLE transactions ADD COLUMN receipt_path TEXT');

    // Split Bills table
    await db.execute('''
    CREATE TABLE split_bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bill_name TEXT NOT NULL,
      total_amount REAL NOT NULL,
      transaction_id INTEGER NOT NULL,
      bill_date TEXT NOT NULL,
      notes TEXT,
      is_paid_by_me INTEGER DEFAULT 1,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
    )
    ''');

    // Split Persons table
    await db.execute('''
    CREATE TABLE split_persons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      split_bill_id INTEGER NOT NULL,
      person_name TEXT NOT NULL,
      share_amount REAL NOT NULL,
      is_paid INTEGER DEFAULT 0,
      paid_date TEXT,
      payment_method TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (split_bill_id) REFERENCES split_bills(id) ON DELETE CASCADE
    )
    ''');
    await db.execute('CREATE INDEX idx_split_status ON split_bills(status)');

    // Savings Goals table
    await db.execute('''
    CREATE TABLE savings_goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      goal_name TEXT NOT NULL,
      target_amount REAL NOT NULL,
      current_amount REAL DEFAULT 0,
      monthly_contribution REAL DEFAULT 0,
      target_date TEXT NOT NULL,
      start_date TEXT NOT NULL,
      description TEXT,
      icon TEXT,
      color TEXT DEFAULT 'FF4CAF50',
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');
    await db.execute('CREATE INDEX idx_goal_status ON savings_goals(status)');

    // Recurring Bills table
    await db.execute('''
    CREATE TABLE recurring_bills (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      category TEXT NOT NULL,
      day_of_month INTEGER NOT NULL,
      is_active INTEGER DEFAULT 1,
      last_paid TEXT,
      created_at TEXT NOT NULL
    )
    ''');
    await db.execute(
      'CREATE INDEX idx_recurring_active ON recurring_bills(is_active)',
    );

    // Assets table
    await db.execute('''
    CREATE TABLE assets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      current_value REAL NOT NULL,
      valuation_date TEXT NOT NULL,
      notes TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Liabilities table
    await db.execute('''
    CREATE TABLE liabilities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      current_balance REAL NOT NULL,
      balance_date TEXT NOT NULL,
      notes TEXT,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Net Worth Snapshots table
    await db.execute('''
    CREATE TABLE net_worth_snapshots (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      snapshot_date TEXT NOT NULL UNIQUE,
      total_assets REAL NOT NULL,
      total_liabilities REAL NOT NULL,
      net_worth REAL NOT NULL,
      created_at TEXT NOT NULL
    )
    ''');
    await db.execute(
      'CREATE INDEX idx_networth_date ON net_worth_snapshots(snapshot_date)',
    );

    // Credit Cards table
    await db.execute('''
    CREATE TABLE credit_cards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      card_name TEXT NOT NULL,
      bank_name TEXT NOT NULL,
      last_4_digits TEXT NOT NULL,
      card_type TEXT NOT NULL,
      credit_limit REAL NOT NULL,
      current_balance REAL DEFAULT 0,
      statement_date TEXT,
      due_date TEXT,
      minimum_due REAL,
      reward_points REAL,
      is_active INTEGER DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');
    await db.execute('CREATE INDEX idx_card_active ON credit_cards(is_active)');
    await db.execute('CREATE INDEX idx_card_due ON credit_cards(due_date)');

    // Income table
    await db.execute('''
    CREATE TABLE income (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      source TEXT NOT NULL,
      category TEXT NOT NULL,
      date TEXT NOT NULL,
      description TEXT,
      sms_body TEXT,
      bank_name TEXT,
      account_number TEXT,
      reference TEXT,
      is_recurring INTEGER DEFAULT 0,
      recurring_frequency TEXT,
      next_expected_date TEXT,
      currency TEXT DEFAULT 'INR',
      is_deleted INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');
    await db.execute('CREATE INDEX idx_income_date ON income(date)');
    await db.execute('CREATE INDEX idx_income_category ON income(category)');

    // Receipts table
    await db.execute('''
    CREATE TABLE receipts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      image_path TEXT NOT NULL,
      amount REAL,
      merchant_name TEXT,
      receipt_date TEXT,
      extracted_text TEXT,
      category TEXT,
      linked_transaction_id INTEGER,
      is_processed INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
    )
    ''');
    await db.execute(
      'CREATE INDEX idx_receipt_processed ON receipts(is_processed)',
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS transactions');
      await _createDB(db, newVersion);
    }

    if (oldVersion < 3) {
      // Add holdings and balances tables
      await db.execute('''
      CREATE TABLE IF NOT EXISTS holdings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        buy_price REAL NOT NULL,
        current_price REAL,
        purchase_date TEXT NOT NULL,
        broker TEXT,
        sms_body TEXT,
        is_active INTEGER DEFAULT 1
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS account_balances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_name TEXT NOT NULL,
        account_number TEXT NOT NULL,
        balance REAL NOT NULL,
        timestamp TEXT NOT NULL,
        sms_body TEXT
      )
      ''');
    }

    if (oldVersion < 4) {
      // Add accounts table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bank_name TEXT NOT NULL,
        account_number TEXT NOT NULL,
        account_type TEXT NOT NULL,
        current_balance REAL,
        icon_name TEXT,
        is_active INTEGER DEFAULT 1
      )
      ''');
    }

    if (oldVersion < 5) {
      // Recreate transactions table with unique constraint
      await db.execute('ALTER TABLE transactions RENAME TO transactions_old');
      await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        merchant_name TEXT NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        sms_body TEXT UNIQUE,
        bank_name TEXT,
        account_number TEXT,
        is_recurring INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0
      )
      ''');

      // Copy data, removing duplicates
      await db.execute('''
      INSERT OR IGNORE INTO transactions 
      SELECT * FROM transactions_old
      ''');

      await db.execute('DROP TABLE transactions_old');

      // Add unique constraint to holdings
      await db.execute('ALTER TABLE holdings RENAME TO holdings_old');
      await db.execute('''
      CREATE TABLE holdings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        buy_price REAL NOT NULL,
        current_price REAL,
        purchase_date TEXT NOT NULL,
        broker TEXT,
        sms_body TEXT UNIQUE,
        is_active INTEGER DEFAULT 1
      )
      ''');

      await db.execute('''
      INSERT OR IGNORE INTO holdings 
      SELECT * FROM holdings_old
      ''');

      await db.execute('DROP TABLE holdings_old');
    }

    if (oldVersion < 6) {
      // Add subscriptions table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_name TEXT NOT NULL,
        amount REAL NOT NULL,
        next_payment_date TEXT,
        state TEXT DEFAULT 'ACTIVE',
        bank_name TEXT,
        umn TEXT,
        category TEXT,
        sms_body TEXT UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
    }

    if (oldVersion < 7) {
      // Add budgets table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        month TEXT NOT NULL,
        spent REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_budgets_month ON budgets(month)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category)',
      );

      // Add custom_categories table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        type TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
      ''');

      // Add rules table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        priority INTEGER DEFAULT 0,
        enabled INTEGER DEFAULT 1,
        conditions TEXT NOT NULL,
        actions TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');

      // Add unrecognized_sms table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS unrecognized_sms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        reason TEXT,
        received_at TEXT NOT NULL,
        is_processed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
      ''');
    }

    if (oldVersion < 8) {
      // Add reason column to unrecognized_sms if it doesn't exist (for existing v7 users)
      try {
        await db.execute('ALTER TABLE unrecognized_sms ADD COLUMN reason TEXT');
      } catch (e) {
        // Column might already exist if created via v7 block above for fresh installs
        debugPrint('Migration v8 error (ignore if column exists): $e');
      }
    }

    if (oldVersion < 9) {
      // Recreate unrecognized_sms to match SmsService schema
      await db.execute(
        'ALTER TABLE unrecognized_sms RENAME TO unrecognized_sms_v8',
      );

      await db.execute('''
      CREATE TABLE unrecognized_sms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        reason TEXT,
        received_at TEXT NOT NULL,
        is_processed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
      ''');

      // Migrate data (best effort)
      try {
        await db.execute('''
        INSERT INTO unrecognized_sms (sender, body, reason, received_at, created_at)
        SELECT sender, body, reason, datetime(timestamp / 1000, 'unixepoch'), created_at 
        FROM unrecognized_sms_v8
        ''');
      } catch (e) {
        debugPrint('Migration v9 data copy error: $e');
      }

      await db.execute('DROP TABLE unrecognized_sms_v8');
    }

    if (oldVersion < 10) {
      // Add new columns to transactions table for parity with Kotlin version
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN reference TEXT');
      } catch (e) {
        debugPrint('Column reference may already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN balance REAL');
      } catch (e) {
        debugPrint('Column balance may already exist: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN credit_limit REAL',
        );
      } catch (e) {
        debugPrint('Column credit_limit may already exist: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN is_from_card INTEGER DEFAULT 0',
        );
      } catch (e) {
        debugPrint('Column is_from_card may already exist: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN currency TEXT DEFAULT \'INR\'',
        );
      } catch (e) {
        debugPrint('Column currency may already exist: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN from_account TEXT',
        );
      } catch (e) {
        debugPrint('Column from_account may already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN to_account TEXT');
      } catch (e) {
        debugPrint('Column to_account may already exist: $e');
      }

      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN transaction_hash TEXT',
        );
      } catch (e) {
        debugPrint('Column transaction_hash may already exist: $e');
      }
    }

    if (oldVersion < 11) {
      // Add missing indexes from version 10
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_budgets_month ON budgets(month)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category)',
      );
    }

    if (oldVersion < 12) {
      // Add IPO Mandates table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS ipo_mandates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL,
        applied_date TEXT NOT NULL,
        revoked_date TEXT,
        account_number TEXT,
        upi_id TEXT,
        bank_name TEXT NOT NULL,
        sms_body TEXT UNIQUE,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ipo_status ON ipo_mandates(status)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ipo_date ON ipo_mandates(applied_date)',
      );
    }

    if (oldVersion < 13) {
      // Clean bad IPO data from overly broad parser
      // Delete Amazon Pay, applno entries, and other subscriptions wrongly marked as IPOs
      await db.delete(
        'ipo_mandates',
        where: '''
          company_name LIKE ? 
          OR company_name LIKE ? 
          OR company_name LIKE ?
          OR company_name LIKE ?
          OR company_name LIKE ?
        ''',
        whereArgs: [
          '%Amazon Pay%',
          'applno%',
          'aplno%',
          '%subscription%',
          'application for%',
        ],
      );

      debugPrint('🧹 Cleaned up bad IPO mandate data from database');
    }

    if (oldVersion < 14) {
      // Add new feature tables
      debugPrint(
        'Adding new feature tables (bills, EMIs, tags, splits, goals, net worth)...',
      );

      // Bill Reminders
      await db.execute('''
      CREATE TABLE IF NOT EXISTS bill_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_name TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        frequency TEXT NOT NULL,
        day_of_month INTEGER NOT NULL,
        next_due_date TEXT,
        last_paid_date TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        is_active INTEGER DEFAULT 1,
        auto_detected INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_status ON bill_reminders(status)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bill_due ON bill_reminders(next_due_date)',
      );

      // EMIs
      await db.execute('''
      CREATE TABLE IF NOT EXISTS emis (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lender_name TEXT NOT NULL,
        type TEXT NOT NULL,
        principal_amount REAL NOT NULL,
        emi_amount REAL NOT NULL,
        interest_rate REAL NOT NULL,
        tenure_months INTEGER NOT NULL,
        paid_months INTEGER DEFAULT 0,
        start_date TEXT NOT NULL,
        end_date TEXT,
        account_number TEXT,
        current_outstanding REAL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_emi_active ON emis(is_active)',
      );

      // Expense Tags
      await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL,
        icon TEXT,
        is_tax_deductible INTEGER DEFAULT 0,
        is_business_expense INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
      ''');

      // Transaction Tags
      await db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES expense_tags(id) ON DELETE CASCADE,
        UNIQUE(transaction_id, tag_id)
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transaction_tags ON transaction_tags(transaction_id)',
      );

      // Add receipt_path to transactions
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN receipt_path TEXT',
        );
      } catch (e) {
        debugPrint('receipt_path column may already exist: $e');
      }

      // Split Bills
      await db.execute('''
      CREATE TABLE IF NOT EXISTS split_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        transaction_id INTEGER NOT NULL,
        bill_date TEXT NOT NULL,
        notes TEXT,
        is_paid_by_me INTEGER DEFAULT 1,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS split_persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        split_bill_id INTEGER NOT NULL,
        person_name TEXT NOT NULL,
        share_amount REAL NOT NULL,
        is_paid INTEGER DEFAULT 0,
        paid_date TEXT,
        payment_method TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (split_bill_id) REFERENCES split_bills(id) ON DELETE CASCADE
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_split_status ON split_bills(status)',
      );

      // Savings Goals
      await db.execute('''
      CREATE TABLE IF NOT EXISTS savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL DEFAULT 0,
        monthly_contribution REAL DEFAULT 0,
        target_date TEXT NOT NULL,
        start_date TEXT NOT NULL,
        description TEXT,
        icon TEXT,
        color TEXT DEFAULT 'FF4CAF50',
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_goal_status ON savings_goals(status)',
      );

      // Assets
      await db.execute('''
      CREATE TABLE IF NOT EXISTS assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        current_value REAL NOT NULL,
        valuation_date TEXT NOT NULL,
        notes TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');

      // Liabilities
      await db.execute('''
      CREATE TABLE IF NOT EXISTS liabilities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        current_balance REAL NOT NULL,
        balance_date TEXT NOT NULL,
        notes TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');

      // Net Worth Snapshots
      await db.execute('''
      CREATE TABLE IF NOT EXISTS net_worth_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        snapshot_date TEXT NOT NULL UNIQUE,
        total_assets REAL NOT NULL,
        total_liabilities REAL NOT NULL,
        net_worth REAL NOT NULL,
        created_at TEXT NOT NULL
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_networth_date ON net_worth_snapshots(snapshot_date)',
      );

      // Add default tags
      final now = DateTime.now().toIso8601String();
      await db.insert('expense_tags', {
        'name': 'Tax Deductible',
        'color': 'FF4CAF50',
        'icon': 'clipboard',
        'is_tax_deductible': 1,
        'is_business_expense': 0,
        'created_at': now,
      });
      await db.insert('expense_tags', {
        'name': 'Business',
        'color': 'FF2196F3',
        'icon': '💼',
        'is_tax_deductible': 0,
        'is_business_expense': 1,
        'created_at': now,
      });
      await db.insert('expense_tags', {
        'name': 'Personal',
        'color': 'FFFF9800',
        'icon': '👤',
        'is_tax_deductible': 0,
        'is_business_expense': 0,
        'created_at': now,
      });

      debugPrint('New feature tables added successfully');
    }

    if (oldVersion < 15) {
      // Nuclear fix: drop and recreate unrecognized_sms with correct schema
      // This is safe because unrecognized SMS data is non-critical and regenerated on next scan
      debugPrint('🔧 Recreating unrecognized_sms with correct schema...');
      try {
        await db.execute('DROP TABLE IF EXISTS unrecognized_sms');
        await db.execute('''
        CREATE TABLE unrecognized_sms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender TEXT NOT NULL,
          body TEXT NOT NULL,
          reason TEXT,
          received_at TEXT NOT NULL DEFAULT '',
          is_processed INTEGER DEFAULT 0,
          created_at TEXT NOT NULL DEFAULT ''
        )
        ''');
        debugPrint('unrecognized_sms table recreated successfully');
      } catch (e) {
        debugPrint('unrecognized_sms recreation error: $e');
      }
    }

    // Version 16: Add Credit Cards, Income, and Receipts tables
    if (oldVersion < 16) {
      debugPrint('🔧 Adding Credit Cards, Income, and Receipts tables...');

      // Credit Cards table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_name TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        last_4_digits TEXT NOT NULL,
        card_type TEXT NOT NULL,
        credit_limit REAL NOT NULL,
        current_balance REAL DEFAULT 0,
        statement_date TEXT,
        due_date TEXT,
        minimum_due REAL,
        reward_points REAL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_card_active ON credit_cards(is_active)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_card_due ON credit_cards(due_date)',
      );

      // Income table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS income (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        source TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        sms_body TEXT,
        bank_name TEXT,
        account_number TEXT,
        reference TEXT,
        is_recurring INTEGER DEFAULT 0,
        recurring_frequency TEXT,
        next_expected_date TEXT,
        currency TEXT DEFAULT 'INR',
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_income_date ON income(date)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_income_category ON income(category)',
      );

      // Receipts table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS receipts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        amount REAL,
        merchant_name TEXT,
        receipt_date TEXT,
        extracted_text TEXT,
        category TEXT,
        linked_transaction_id INTEGER,
        is_processed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
      )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_receipt_processed ON receipts(is_processed)',
      );

      debugPrint(
        'Credit Cards, Income, and Receipts tables added successfully',
      );
    }

    // Version 17: Fix unrecognized_sms schema (missing reason/received_at/is_processed columns)
    if (oldVersion < 17) {
      debugPrint('🔧 v17: Fixing unrecognized_sms schema...');
      try {
        await db.execute('DROP TABLE IF EXISTS unrecognized_sms');
        await db.execute('''
        CREATE TABLE unrecognized_sms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender TEXT NOT NULL,
          body TEXT NOT NULL,
          reason TEXT,
          received_at TEXT NOT NULL DEFAULT '',
          is_processed INTEGER DEFAULT 0,
          created_at TEXT NOT NULL DEFAULT ''
        )
        ''');
        debugPrint('unrecognized_sms schema fixed');
      } catch (e) {
        debugPrint('v17 migration error: $e');
      }
    }

    // v18: Add performance indexes on transactions
    if (oldVersion < 18) {
      debugPrint('🔧 v18: Adding transaction indexes...');
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_txn_date ON transactions(date)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_txn_type ON transactions(type)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_txn_deleted ON transactions(is_deleted)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_txn_category ON transactions(category)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_txn_hash ON transactions(transaction_hash)',
        );
        debugPrint('Transaction indexes added');
      } catch (e) {
        debugPrint('v18 migration error: $e');
      }
    }
  }

  /// Auto-creates or updates bank account based on parsed transaction SMS data
  Future<void> upsertAccountFromTransaction(Transaction transaction) async {
    if (transaction.accountNumber == null || transaction.accountNumber!.isEmpty)
      return;

    final db = await instance.database;
    final accountNum = transaction.accountNumber!;
    final bankName = transaction.bankName ?? 'Unknown Bank';

    // Check if account exists
    final accounts = await db.query(
      'accounts',
      where: 'account_number = ?',
      whereArgs: [accountNum],
    );

    if (accounts.isEmpty) {
      // Auto-create account with null balance so user can enter initial balance later
      await db.insert('accounts', {
        'bank_name': bankName,
        'account_number': accountNum,
        'account_type': transaction.isFromCard ? 'Credit Card' : 'Savings',
        'current_balance': transaction.balance,
        'is_active': 1,
      });
    } else {
      // Account exists, update balance if needed
      final accountMap = accounts.first;
      double? dbBalance = accountMap['current_balance'] as double?;
      double? newBalance;

      // If the SMS explicitly contains the balance exactly, sync it
      if (transaction.balance != null) {
        newBalance = transaction.balance;
      } else if (dbBalance != null) {
        // Dynamically adjust balance if it was already initialized
        if (transaction.type.name == 'expense' ||
            transaction.type.name == 'credit') {
          newBalance = dbBalance - transaction.amount;
        } else if (transaction.type.name == 'income') {
          newBalance = dbBalance + transaction.amount;
        }
      }

      if (newBalance != null && newBalance != dbBalance) {
        await db.update(
          'accounts',
          {'current_balance': newBalance},
          where: 'id = ?',
          whereArgs: [accountMap['id']],
        );
      }
    }
  }

  Future<int> create(Transaction transaction) async {
    await upsertAccountFromTransaction(transaction);

    final db = await instance.database;
    // Replace allows updating existing transactions with better parsed data
    return await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Transaction>> readAllTransactions() async {
    final db = await instance.database;
    final orderBy = 'date DESC';
    final result = await db.query('transactions', orderBy: orderBy);

    return result.map((json) => Transaction.fromMap(json)).toList();
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createBalance(Map<String, dynamic> balance) async {
    final db = await instance.database;
    return await db.insert('account_balances', balance);
  }

  Future<List<Map<String, dynamic>>> readLatestBalances() async {
    final db = await instance.database;
    // Get latest balance for each account
    return await db.rawQuery('''
      SELECT * FROM account_balances 
      WHERE id IN (
        SELECT MAX(id) FROM account_balances 
        GROUP BY account_number
      )
      ORDER BY timestamp DESC
    ''');
  }

  Future<Map<String, dynamic>?> getLatestBalanceForAccount(
    String accountNumber,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'account_balances',
      where: 'account_number = ?',
      whereArgs: [accountNumber],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Account methods
  Future<int> createAccount(Map<String, dynamic> account) async {
    final db = await instance.database;
    return await db.insert('accounts', account);
  }

  Future<List<Map<String, dynamic>>> readAllAccounts() async {
    final db = await instance.database;
    return await db.query(
      'accounts',
      where: 'is_active = 1',
      orderBy: 'bank_name ASC',
    );
  }

  Future<int> updateAccount(int id, Map<String, dynamic> account) async {
    final db = await instance.database;
    return await db.update(
      'accounts',
      account,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await instance.database;
    return await db.update(
      'accounts',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionsByAccount(
    String accountNumber,
  ) async {
    final db = await instance.database;
    return await db.query(
      'transactions',
      where: 'account_number = ? AND is_deleted = 0',
      whereArgs: [accountNumber],
      orderBy: 'date DESC',
    );
  }

  // Subscription methods
  Future<int> createSubscription(Map<String, dynamic> subscription) async {
    final db = await instance.database;
    return await db.insert(
      'subscriptions',
      subscription,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> readActiveSubscriptions() async {
    final db = await instance.database;
    final results = await db.query(
      'subscriptions',
      where: 'state = ?',
      whereArgs: ['ACTIVE'],
      orderBy: 'merchant_name ASC',
    );
    debugPrint(
      'Database query returned ${results.length} active subscriptions',
    );
    for (var sub in results) {
      debugPrint(
        '  - ${sub['merchant_name']}: ₹${sub['amount']} (state: ${sub['state']})',
      );
    }
    return results;
  }

  Future<int> updateSubscription(
    int id,
    Map<String, dynamic> subscription,
  ) async {
    final db = await instance.database;
    return await db.update(
      'subscriptions',
      subscription,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSubscription(int id) async {
    final db = await instance.database;
    return await db.update(
      'subscriptions',
      {'state': 'HIDDEN'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Additional methods for enhanced functionality
  Future<int> update(Transaction transaction) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> softDelete(int id) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUnrecognizedSMS() async {
    final db = await instance.database;
    return await db.query('unrecognized_sms', orderBy: 'created_at DESC');
  }

  Future<int> deleteUnrecognizedSMS(int id) async {
    final db = await instance.database;
    return await db.delete(
      'unrecognized_sms',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getBudgetsForMonth(String month) async {
    final db = await instance.database;
    return await db.query('budgets', where: 'month = ?', whereArgs: [month]);
  }

  Future<int> createOrUpdateBudget(Map<String, dynamic> budget) async {
    final db = await instance.database;
    final month = budget['month'];
    final category = budget['category'];

    // Check if budget exists
    final existing = await db.query(
      'budgets',
      where: 'month = ? AND category = ?',
      whereArgs: [month, category],
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'budgets',
        budget,
        where: 'month = ? AND category = ?',
        whereArgs: [month, category],
      );
    } else {
      return await db.insert('budgets', budget);
    }
  }

  Future<List<Map<String, dynamic>>> getCustomCategories() async {
    final db = await instance.database;
    return await db.query('custom_categories', orderBy: 'name ASC');
  }

  Future<int> createCustomCategory(Map<String, dynamic> category) async {
    final db = await instance.database;
    return await db.insert('custom_categories', category);
  }

  Future<List<Map<String, dynamic>>> getRules() async {
    final db = await instance.database;
    return await db.query('rules', orderBy: 'priority DESC, created_at ASC');
  }

  Future<int> createRule(Map<String, dynamic> rule) async {
    final db = await instance.database;
    return await db.insert('rules', rule);
  }

  Future<int> updateRule(int id, Map<String, dynamic> rule) async {
    final db = await instance.database;
    return await db.update('rules', rule, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRule(int id) async {
    final db = await instance.database;
    return await db.delete('rules', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Bill Reminders ====================
  Future<int> insertBillReminder(Map<String, dynamic> bill) async {
    final db = await instance.database;
    return await db.insert('bill_reminders', bill);
  }

  Future<List<Map<String, dynamic>>> getAllBillReminders() async {
    final db = await instance.database;
    return await db.query(
      'bill_reminders',
      where: 'is_active = 1',
      orderBy: 'next_due_date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getUpcomingBills(int days) async {
    final db = await instance.database;
    final futureDate = DateTime.now()
        .add(Duration(days: days))
        .toIso8601String();
    return await db.query(
      'bill_reminders',
      where: 'is_active = 1 AND status = ? AND next_due_date <= ?',
      whereArgs: ['pending', futureDate],
      orderBy: 'next_due_date ASC',
    );
  }

  Future<int> updateBillReminder(int id, Map<String, dynamic> bill) async {
    final db = await instance.database;
    return await db.update(
      'bill_reminders',
      bill,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteBillReminder(int id) async {
    final db = await instance.database;
    return await db.delete('bill_reminders', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== EMIs ====================
  Future<int> insertEmi(Map<String, dynamic> emi) async {
    final db = await instance.database;
    return await db.insert('emis', emi);
  }

  Future<List<Map<String, dynamic>>> getAllEmis() async {
    final db = await instance.database;
    return await db.query(
      'emis',
      where: 'is_active = 1',
      orderBy: 'start_date DESC',
    );
  }

  Future<int> updateEmi(int id, Map<String, dynamic> emi) async {
    final db = await instance.database;
    return await db.update('emis', emi, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteEmi(int id) async {
    final db = await instance.database;
    return await db.delete('emis', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Expense Tags ====================
  Future<int> insertExpenseTag(Map<String, dynamic> tag) async {
    final db = await instance.database;
    return await db.insert('expense_tags', tag);
  }

  Future<List<Map<String, dynamic>>> getAllExpenseTags() async {
    final db = await instance.database;
    return await db.query('expense_tags', orderBy: 'name ASC');
  }

  Future<int> addTagToTransaction(int transactionId, int tagId) async {
    final db = await instance.database;
    return await db.insert('transaction_tags', {
      'transaction_id': transactionId,
      'tag_id': tagId,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> removeTagFromTransaction(int transactionId, int tagId) async {
    final db = await instance.database;
    return await db.delete(
      'transaction_tags',
      where: 'transaction_id = ? AND tag_id = ?',
      whereArgs: [transactionId, tagId],
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionTags(
    int transactionId,
  ) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT et.* FROM expense_tags et
      INNER JOIN transaction_tags tt ON et.id = tt.tag_id
      WHERE tt.transaction_id = ?
    ''',
      [transactionId],
    );
  }

  Future<Map<String, double>> getTaggedExpensesSummary() async {
    final db = await instance.database;
    final results = await db.rawQuery('''
      SELECT et.name, SUM(t.amount) as total
      FROM transactions t
      INNER JOIN transaction_tags tt ON t.id = tt.transaction_id
      INNER JOIN expense_tags et ON tt.tag_id = et.id
      WHERE t.type = 'expense' AND t.is_deleted = 0
      GROUP BY et.id, et.name
    ''');

    return Map.fromEntries(
      results.map(
        (row) =>
            MapEntry(row['name'] as String, (row['total'] as num).toDouble()),
      ),
    );
  }

  // ==================== Split Bills ====================
  Future<int> insertSplitBill(Map<String, dynamic> bill) async {
    final db = await instance.database;
    return await db.insert('split_bills', bill);
  }

  Future<int> insertSplitPerson(Map<String, dynamic> person) async {
    final db = await instance.database;
    return await db.insert('split_persons', person);
  }

  Future<List<Map<String, dynamic>>> getAllSplitBills() async {
    final db = await instance.database;
    return await db.query('split_bills', orderBy: 'bill_date DESC');
  }

  Future<List<Map<String, dynamic>>> getSplitPersons(int splitBillId) async {
    final db = await instance.database;
    return await db.query(
      'split_persons',
      where: 'split_bill_id = ?',
      whereArgs: [splitBillId],
    );
  }

  Future<double> getTotalOwedToMe() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT SUM(sp.share_amount) as total
      FROM split_persons sp
      INNER JOIN split_bills sb ON sp.split_bill_id = sb.id
      WHERE sb.is_paid_by_me = 1 AND sp.is_paid = 0
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalIOweToOthers() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT SUM(sb.total_amount) as total
      FROM split_bills sb
      WHERE sb.is_paid_by_me = 0 AND sb.status != 'fullPaid'
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> updateSplitPerson(int id, Map<String, dynamic> person) async {
    final db = await instance.database;
    return await db.update(
      'split_persons',
      person,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateSplitBill(int id, Map<String, dynamic> bill) async {
    final db = await instance.database;
    return await db.update(
      'split_bills',
      bill,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Savings Goals ====================
  Future<int> insertSavingsGoal(Map<String, dynamic> goal) async {
    final db = await instance.database;
    return await db.insert('savings_goals', goal);
  }

  Future<List<Map<String, dynamic>>> getAllSavingsGoals() async {
    final db = await instance.database;
    return await db.query(
      'savings_goals',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'target_date ASC',
    );
  }

  Future<int> updateSavingsGoal(int id, Map<String, dynamic> goal) async {
    final db = await instance.database;
    return await db.update(
      'savings_goals',
      goal,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSavingsGoal(int id) async {
    final db = await instance.database;
    return await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Recurring Bills ====================
  Future<int> insertRecurringBill(Map<String, dynamic> bill) async {
    final db = await instance.database;
    return await db.insert('recurring_bills', bill);
  }

  Future<List<Map<String, dynamic>>> getAllRecurringBills() async {
    final db = await instance.database;
    return await db.query('recurring_bills', orderBy: 'day_of_month ASC');
  }

  Future<int> updateRecurringBill(int id, Map<String, dynamic> bill) async {
    final db = await instance.database;
    return await db.update(
      'recurring_bills',
      bill,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteRecurringBill(int id) async {
    final db = await instance.database;
    return await db.delete('recurring_bills', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== Net Worth ====================
  Future<int> insertAsset(Map<String, dynamic> asset) async {
    final db = await instance.database;
    return await db.insert('assets', asset);
  }

  Future<int> insertLiability(Map<String, dynamic> liability) async {
    final db = await instance.database;
    return await db.insert('liabilities', liability);
  }

  Future<List<Map<String, dynamic>>> getAllAssets() async {
    final db = await instance.database;
    return await db.query(
      'assets',
      where: 'is_active = 1',
      orderBy: 'current_value DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllLiabilities() async {
    final db = await instance.database;
    return await db.query(
      'liabilities',
      where: 'is_active = 1',
      orderBy: 'current_balance DESC',
    );
  }

  Future<double> getTotalAssets() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(current_value) as total FROM assets WHERE is_active = 1',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getTotalLiabilities() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(current_balance) as total FROM liabilities WHERE is_active = 1',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> createNetWorthSnapshot() async {
    final db = await instance.database;
    final assets = await getTotalAssets();
    final liabilities = await getTotalLiabilities();
    final netWorth = assets - liabilities;

    return await db.insert('net_worth_snapshots', {
      'snapshot_date': DateTime.now().toIso8601String().split('T')[0],
      'total_assets': assets,
      'total_liabilities': liabilities,
      'net_worth': netWorth,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getNetWorthHistory(int months) async {
    final db = await instance.database;
    return await db.query(
      'net_worth_snapshots',
      orderBy: 'snapshot_date DESC',
      limit: months,
    );
  }

  Future<int> updateAsset(int id, Map<String, dynamic> asset) async {
    final db = await instance.database;
    return await db.update('assets', asset, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateLiability(int id, Map<String, dynamic> liability) async {
    final db = await instance.database;
    return await db.update(
      'liabilities',
      liability,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAsset(int id) async {
    final db = await instance.database;
    return await db.delete('assets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteLiability(int id) async {
    final db = await instance.database;
    return await db.delete('liabilities', where: 'id = ?', whereArgs: [id]);
  }
}
