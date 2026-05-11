import 'package:flutter/material.dart';

/// ==========================================
/// Luminew 設計系統 - 核心顏色中心 (AppColors)
/// ==========================================
class AppColors {
  // --- 核心品牌色 ---
  static const Color primaryPurple = Color(0xFFAD9DC7);   // 核心紫色 (100%)
  static const Color deepIndigo = Color(0xFF675B83);     // 文字深紫色 (100%)
  static const Color gooseYellow = Color(0xFFFFFDF0);    // 背景鵝黃色
  static const Color surfaceWhite = Colors.white;        // 純白表面

  // --- 質感色系 (由透明度 0.85, 0.65, 0.45 轉換而來) ---
  // 這些顏色在鵝黃背景上能產生完美的通透感，且不會因為透明度計算導致 UI 變醜
  static const Color primaryPurpleSoft = Color(0xFFB9ABCD);   // 85% 紫：你最喜歡的按鈕色
  static const Color primaryPurpleMuted = Color(0xFFCABED8);  // 65% 紫：中等深度
  static const Color primaryPurpleLight = Color(0xFFDBD2E4);  // 45% 紫：淺標籤色
  static const Color purpleSurface = Color(0xFFF3EFEA);       // 15% 紫：卡片底色
  static const Color purpleBorder = Color(0xFFFBF8EE);        // 5% 紫：細邊框色
  
  // --- 專用背景與導覽 ---
  static const Color headerPurple = Color(0xFFAD9DC7);       // 導覽列主色
  static const Color headerPurpleGlass = Color(0x99AD9DC7);  // 導覽列磨砂色 (約 60% 透明)
  static const Color navBarBackground = Color(0xCCAD9DC7);   // 底端導覽列背景色 (80% 透明度)
  
  // --- 功能性顏色 (狀態與情緒) ---
  static const Color success = Color(0xFF8ECABB);        // 成功/完成：正面情緒、正確反饋
  static const Color warning = Color(0xFFFDC78A);        // 警告/提醒：需要注意的資訊
  static const Color error = Color(0xFFFF6B6B);          // 錯誤/危險：警示、刪除、失敗
  
  // 情緒分析專用色 (情緒指標圖表使用)
  static const Color confident = Color(0xFFFDE68A);      // 自信黃
  static const Color nervous = Color(0xFF94C5EE);        // 緊張藍
  static const Color passion = Color(0xFFECAEB5);        // 熱情粉
  static const Color relaxed = Color(0xFFA0DBC4);        // 放鬆綠

  // --- 文字專用色 ---
  static const Color textMain = Color(0xFF333333);       // 主要內容：高對比黑
  static const Color textGrey = Color(0xFF5A5A5A);       // 次要敘述：質感深灰
  static const Color textLightGrey = Color(0xFF9E9E9E);  // 輔助/提示：淺灰色
  static const Color textDisabled = Color(0xFFCCCCCC);   // 停用狀態：失效文字
}

/// ==========================================
/// Luminew 設計系統 - 文字樣式規範 (AppTextStyles)
/// ==========================================
class AppTextStyles {
  // --- 標題系列 ---
  static const TextStyle h1 = TextStyle(
    color: AppColors.deepIndigo,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  static const TextStyle h2 = TextStyle(
    color: AppColors.deepIndigo,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle h3 = TextStyle(
    color: AppColors.deepIndigo,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  // --- 內容系列 ---
  static const TextStyle bodyLarge = TextStyle(
    color: AppColors.textMain,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: AppColors.textGrey,
    fontSize: 14,
    height: 1.5, // 增加行高提升閱讀舒適度
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textLightGrey,
    fontSize: 12,
  );

  // --- 按鈕與標籤 ---
  static const TextStyle buttonText = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.0,
  );

  static const TextStyle labelTiny = TextStyle(
    color: AppColors.primaryPurple,
    fontSize: 11,
    fontWeight: FontWeight.bold,
  );
}

/// ==========================================
/// Luminew 設計系統 - 間距與佈局 (AppSpacings)
/// ==========================================
class AppSpacings {
  // 外部間距 (Padding / Margin)
  static const double pagePadding = 24.0;  // 頁面兩側留白
  static const double cardPadding = 16.0;  // 卡片內部留白
  
  // 內部元素間隙 (Gap)
  static const double gapXL = 32.0;        // 大區塊間距
  static const double gapL = 20.0;         // 一般元件間距
  static const double gapM = 12.0;         // 標題與內容間距
  static const double gapS = 8.0;          // 微小間距
}

/// ==========================================
/// Luminew 設計系統 - 物理特性 (AppDesign)
/// ==========================================
class AppDesign {
  // 導角規格 (Radius)
  static const double radiusL = 24.0;      // 大導角：主卡片
  static const double radiusM = 16.0;      // 中導角：按鈕、輸入框
  static const double radiusS = 8.0;       // 小導角：標籤、小型元件
  static const double radiusCircle = 100.0; // 圓形：頭像

  // 陰影規格 (Shadows)
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: AppColors.deepIndigo.withOpacity(0.04),
      blurRadius: 15,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get accentShadow => [
    BoxShadow(
      color: AppColors.primaryPurple.withOpacity(0.08),
      blurRadius: 20,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ];

  // 動態曲線 (Curves)
  static const Curve defaultCurve = Curves.easeInOutQuart;
  static const Duration defaultDuration = Duration(milliseconds: 300);
}
