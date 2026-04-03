import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhanpath/utils/category_icons.dart';

void main() {
  group('CategoryIcons', () {
    test('icons map contains main categories', () {
      expect(CategoryIcons.icons.containsKey('Food & Dining'), true);
      expect(CategoryIcons.icons.containsKey('Transportation'), true);
      expect(CategoryIcons.icons.containsKey('Shopping'), true);
      expect(CategoryIcons.icons.containsKey('Entertainment'), true);
      expect(CategoryIcons.icons.containsKey('Utilities'), true);
      expect(CategoryIcons.icons.containsKey('Healthcare'), true);
      expect(CategoryIcons.icons.containsKey('Education'), true);
    });

    test('icons map contains student-specific categories', () {
      expect(CategoryIcons.icons.containsKey('Tuition'), true);
      expect(CategoryIcons.icons.containsKey('Books & Stationery'), true);
      expect(CategoryIcons.icons.containsKey('Hostel & Rent'), true);
      expect(CategoryIcons.icons.containsKey('Mess & Canteen'), true);
      expect(CategoryIcons.icons.containsKey('College Transport'), true);
      expect(CategoryIcons.icons.containsKey('Printing & Copies'), true);
      expect(CategoryIcons.icons.containsKey('Online Courses'), true);
      expect(CategoryIcons.icons.containsKey('Exam Fees'), true);
      expect(CategoryIcons.icons.containsKey('Lab & Project'), true);
      expect(CategoryIcons.icons.containsKey('Mobile & Internet'), true);
      expect(CategoryIcons.icons.containsKey('Laundry'), true);
      expect(CategoryIcons.icons.containsKey('Personal Care'), true);
      expect(CategoryIcons.icons.containsKey('Hangout & Cafe'), true);
      expect(CategoryIcons.icons.containsKey('Gifts & Social'), true);
      expect(CategoryIcons.icons.containsKey('Emergency'), true);
      expect(CategoryIcons.icons.containsKey('Groceries'), true);
      expect(CategoryIcons.icons.containsKey('Medicines'), true);
    });

    test('getIcon returns correct icon for known categories', () {
      expect(CategoryIcons.getIcon('Food & Dining'), Icons.restaurant_rounded);
      expect(CategoryIcons.getIcon('Tuition'), Icons.school_rounded);
      expect(CategoryIcons.getIcon('Books & Stationery'), Icons.menu_book_rounded);
      expect(CategoryIcons.getIcon('Hostel & Rent'), Icons.home_rounded);
      expect(CategoryIcons.getIcon('Mess & Canteen'), Icons.restaurant_menu_rounded);
      expect(CategoryIcons.getIcon('College Transport'), Icons.directions_bus_rounded);
      expect(CategoryIcons.getIcon('Online Courses'), Icons.laptop_rounded);
      expect(CategoryIcons.getIcon('Emergency'), Icons.emergency_rounded);
    });

    test('getIcon returns fallback for unknown category', () {
      expect(CategoryIcons.getIcon('NonExistentCategory'), Icons.inventory_2_rounded);
      expect(CategoryIcons.getIcon(''), Icons.inventory_2_rounded);
      expect(CategoryIcons.getIcon('random'), Icons.inventory_2_rounded);
    });

    test('studentCategories list is not empty', () {
      expect(CategoryIcons.studentCategories.isNotEmpty, true);
      expect(CategoryIcons.studentCategories.length, greaterThanOrEqualTo(15));
    });

    test('all student categories have corresponding icons', () {
      for (final cat in CategoryIcons.studentCategories) {
        expect(
          CategoryIcons.icons.containsKey(cat),
          true,
          reason: 'Category "$cat" has no icon mapping',
        );
      }
    });

    test('generalCategories list is not empty', () {
      expect(CategoryIcons.generalCategories.isNotEmpty, true);
    });

    test('getAllCategories returns complete map', () {
      final all = CategoryIcons.getAllCategories();
      expect(all.length, CategoryIcons.icons.length);
      expect(all.containsKey('Food & Dining'), true);
      expect(all.containsKey('Tuition'), true);
    });

    test('getStudentCategories returns correct subset', () {
      final studentCats = CategoryIcons.getStudentCategories();
      expect(studentCats.length, CategoryIcons.studentCategories.length);
      for (final cat in CategoryIcons.studentCategories) {
        expect(studentCats.containsKey(cat), true);
        expect(studentCats[cat], isNotNull);
      }
    });

    test('student categories include essential student needs', () {
      final cats = CategoryIcons.studentCategories;
      expect(cats.contains('Food & Dining'), true);
      expect(cats.contains('Mess & Canteen'), true);
      expect(cats.contains('Books & Stationery'), true);
      expect(cats.contains('College Transport'), true);
      expect(cats.contains('Tuition'), true);
      expect(cats.contains('Hostel & Rent'), true);
      expect(cats.contains('Mobile & Internet'), true);
    });

    test('no duplicates in studentCategories', () {
      final unique = CategoryIcons.studentCategories.toSet();
      expect(unique.length, CategoryIcons.studentCategories.length);
    });

    test('no duplicates in generalCategories', () {
      final unique = CategoryIcons.generalCategories.toSet();
      expect(unique.length, CategoryIcons.generalCategories.length);
    });

    test('all icons are valid IconData', () {
      for (final entry in CategoryIcons.icons.entries) {
        expect(
          entry.value,
          isA<IconData>(),
          reason: 'Icon for "${entry.key}" should be IconData',
        );
        expect(
          entry.value.codePoint,
          greaterThan(0),
          reason: 'Icon for "${entry.key}" should have a valid codepoint',
        );
      }
    });
  });
}
