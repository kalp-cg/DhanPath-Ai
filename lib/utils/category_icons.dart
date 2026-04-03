import 'package:flutter/material.dart';

class CategoryIcons {
  static const Map<String, IconData> icons = {
    // Main Categories
    'Food & Dining': Icons.restaurant_rounded,
    'Transportation': Icons.directions_car_rounded,
    'Shopping': Icons.shopping_cart_rounded,
    'Entertainment': Icons.movie_rounded,
    'Utilities': Icons.lightbulb_outline_rounded,
    'Healthcare': Icons.local_hospital_rounded,
    'Education': Icons.school_rounded,
    'Fitness': Icons.fitness_center_rounded,
    'Banking': Icons.account_balance_rounded,
    'IPO': Icons.trending_up_rounded,
    'IPO Application': Icons.trending_up_rounded,
    'IPO Refund': Icons.account_balance_wallet_rounded,

    // Student-Specific Categories
    'Tuition': Icons.school_rounded,
    'Books & Stationery': Icons.menu_book_rounded,
    'Hostel & Rent': Icons.home_rounded,
    'Mess & Canteen': Icons.restaurant_menu_rounded,
    'College Transport': Icons.directions_bus_rounded,
    'Printing & Copies': Icons.print_rounded,
    'Online Courses': Icons.laptop_rounded,
    'Exam Fees': Icons.assignment_rounded,
    'Lab & Project': Icons.science_rounded,
    'Mobile & Internet': Icons.smartphone_rounded,
    'Laundry': Icons.local_laundry_service_rounded,
    'Personal Care': Icons.spa_rounded,
    'Hangout & Cafe': Icons.local_cafe_rounded,
    'Gifts & Social': Icons.card_giftcard_rounded,
    'Emergency': Icons.emergency_rounded,
    'Groceries': Icons.local_grocery_store_rounded,
    'Medicines': Icons.medication_rounded,

    // Transaction Types
    'Income': Icons.attach_money_rounded,
    'Credit': Icons.credit_card_rounded,
    'Transfer': Icons.swap_horiz_rounded,
    'Investment': Icons.bar_chart_rounded,
    'Subscription': Icons.notifications_rounded,

    // Default
    'Uncategorized': Icons.inventory_2_rounded,
    'Unknown': Icons.help_outline_rounded,
    'Others': Icons.inventory_2_rounded,
  };

  /// Student-specific categories for quick selection
  static const List<String> studentCategories = [
    'Food & Dining',
    'Mess & Canteen',
    'Books & Stationery',
    'College Transport',
    'Tuition',
    'Hostel & Rent',
    'Mobile & Internet',
    'Entertainment',
    'Hangout & Cafe',
    'Online Courses',
    'Printing & Copies',
    'Exam Fees',
    'Lab & Project',
    'Shopping',
    'Laundry',
    'Personal Care',
    'Medicines',
    'Groceries',
    'Gifts & Social',
    'Emergency',
    'Others',
  ];

  /// All general categories
  static const List<String> generalCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Utilities',
    'Healthcare',
    'Education',
    'Fitness',
    'Banking',
    'Others',
  ];

  /// Get icon for a category, with fallback to default
  static IconData getIcon(String category) {
    return icons[category] ?? icons['Uncategorized']!;
  }

  /// Get all categories with their icons
  static Map<String, IconData> getAllCategories() {
    return Map.from(icons);
  }

  /// Get student categories with icons
  static Map<String, IconData> getStudentCategories() {
    return {
      for (var cat in studentCategories)
        cat: icons[cat] ?? icons['Uncategorized']!,
    };
  }
}
