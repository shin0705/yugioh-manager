import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'pages/card_list_page.dart';
import 'pages/deck_list_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/auth_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

// ── 테마 상태 ──────────────────────────────────────────────────
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);
  void toggle() {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeNotifier = ThemeNotifier();

// ── 라이트 팔레트 ──────────────────────────────────────────────
class AppColors {
  static const bg            = Color(0xFFF4F6FA);
  static const surface       = Color(0xFFFFFFFF);
  static const surfaceAlt    = Color(0xFFF0F3F9);
  static const sidebar       = Color(0xFF1E2D40);
  static const sidebarText   = Color(0xFFCDD5E0);
  static const sidebarActive = Color(0xFF3B82F6);
  static const textPrimary   = Color(0xFF1A2235);
  static const textSecondary = Color(0xFF5A6A85);
  static const textMuted     = Color(0xFF9BA8BC);
  static const accent        = Color(0xFF3B82F6);
  static const accentLight   = Color(0xFFEBF2FF);
  static const border        = Color(0xFFE2E8F2);
  static const borderLight   = Color(0xFFF0F3F9);
  static const monster       = Color(0xFFE8823A);
  static const monsterBg     = Color(0xFFFFF4EC);
  static const magic         = Color(0xFF22C55E);
  static const magicBg       = Color(0xFFECFDF5);
  static const trap          = Color(0xFFA855F7);
  static const trapBg        = Color(0xFFF5F0FF);
}

// ── 다크 팔레트 ────────────────────────────────────────────────
class DarkColors {
  static const bg            = Color(0xFF0F1923);
  static const surface       = Color(0xFF1A2535);
  static const surfaceAlt    = Color(0xFF243044);
  static const sidebar       = Color(0xFF111C2B);
  static const textPrimary   = Color(0xFFE8EFF8);
  static const textSecondary = Color(0xFF8FA3BD);
  static const textMuted     = Color(0xFF4E6278);
  static const border        = Color(0xFF263348);
  static const borderLight   = Color(0xFF1D2D3E);
}

// ── 동적 색상 헬퍼 ─────────────────────────────────────────────
class AppTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? DarkColors.bg : AppColors.bg;

  static Color surface(BuildContext context) =>
      isDark(context) ? DarkColors.surface : AppColors.surface;

  static Color surfaceAlt(BuildContext context) =>
      isDark(context) ? DarkColors.surfaceAlt : AppColors.surfaceAlt;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? DarkColors.textPrimary : AppColors.textPrimary;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? DarkColors.textSecondary : AppColors.textSecondary;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? DarkColors.textMuted : AppColors.textMuted;

  static Color border(BuildContext context) =>
      isDark(context) ? DarkColors.border : AppColors.border;

  static Color borderLight(BuildContext context) =>
      isDark(context) ? DarkColors.borderLight : AppColors.borderLight;

  // 다크모드에서도 accent 계열은 약간 밝게
  static const accent      = AppColors.accent;
  static const accentLight = AppColors.accentLight;
  static const monster     = AppColors.monster;
  static const monsterBg   = AppColors.monsterBg;
  static const magic       = AppColors.magic;
  static const magicBg     = AppColors.magicBg;
  static const trap        = AppColors.trap;
  static const trapBg      = AppColors.trapBg;

  // 다크모드에서 accentLight 대용
  static Color accentLightAdaptive(BuildContext context) =>
      isDark(context)
          ? AppColors.accent.withOpacity(0.15)
          : AppColors.accentLight;

  static Color monsterBgAdaptive(BuildContext context) =>
      isDark(context)
          ? AppColors.monster.withOpacity(0.15)
          : AppColors.monsterBg;

  static Color magicBgAdaptive(BuildContext context) =>
      isDark(context)
          ? AppColors.magic.withOpacity(0.15)
          : AppColors.magicBg;

  static Color trapBgAdaptive(BuildContext context) =>
      isDark(context)
          ? AppColors.trap.withOpacity(0.15)
          : AppColors.trapBg;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '유희왕 카드 관리',
          themeMode: mode,
          theme: _buildLight(),
          darkTheme: _buildDark(),
          home: const AuthGate(),
        );
      },
    );
  }

  ThemeData _buildLight() => ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.accent, width: 1.5),
          ),
        ),
      );

  ThemeData _buildDark() => ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: DarkColors.bg,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: DarkColors.surface,
          foregroundColor: DarkColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: DarkColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        cardTheme: CardThemeData(
          color: DarkColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: DarkColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: DarkColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: DarkColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: DarkColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          hintStyle: TextStyle(color: DarkColors.textMuted),
        ),
        // 다크 모드 DropdownButton 배경
        popupMenuTheme: PopupMenuThemeData(
          color: DarkColors.surface,
        ),
      );
}

// ── AuthGate ──────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MainShell();
        }
        return const AuthPage();
      },
    );
  }
}

// ── 스플래시 ──────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.style_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── MainShell ─────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final _auth = AuthService();

  final List<_NavItem> _navItems = [
    _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: '메인'),
    _NavItem(
        icon: Icons.style_outlined,
        activeIcon: Icons.style_rounded,
        label: '카드 관리'),
    _NavItem(
        icon: Icons.view_list_outlined,
        activeIcon: Icons.view_list_rounded,
        label: '덱 관리'),
    _NavItem(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart_rounded,
        label: '통계'),
  ];

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _WelcomePage(
            onNavigate: (i) => setState(() => _selectedIndex = i));
      case 1:
        return const CardListPage();
      case 2:
        return DeckListPage();
      case 3:
        return const DashboardPage();
      default:
        return const SizedBox();
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('로그아웃',
            style: TextStyle(
                color: AppTheme.textPrimary(context),
                fontWeight: FontWeight.w700)),
        content: Text('정말 로그아웃하시겠습니까?',
            style: TextStyle(
                color: AppTheme.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소',
                style: TextStyle(
                    color: AppTheme.textSecondary(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.of(context).size.width > 700;
    final bg = AppTheme.bg(context);
    final surface = AppTheme.surface(context);
    final textMuted = AppTheme.textMuted(context);

    if (isWide) {
      return Scaffold(
        backgroundColor: bg,
        body: Row(children: [
          _Sidebar(
            navItems: _navItems,
            selectedIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            onLogout: _confirmLogout,
          ),
          Expanded(child: _buildPage(_selectedIndex)),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: _navItems
            .map((e) => BottomNavigationBarItem(
                  icon: Icon(e.icon),
                  activeIcon: Icon(e.activeIcon),
                  label: e.label,
                ))
            .toList(),
      ),
    );
  }
}

// ── 사이드바 ──────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final List<_NavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.navItems,
    required this.selectedIndex,
    required this.onTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? '사용자');

    final userId =
        user?.email?.replaceAll('@yugioh.app', '') ?? '';

    return Container(
      width: 220,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 로고
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 28),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF2563EB)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.style_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('유희왕\n카드 관리',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.4)),
              ),
            ]),
          ),

          Divider(
              color: Colors.white.withOpacity(0.1), height: 1),
          const SizedBox(height: 12),

          // 메뉴
          ...navItems.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final sel = selectedIndex == i;
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 2),
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.accent.withOpacity(0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: sel
                        ? Border.all(
                            color: AppColors.accent
                                .withOpacity(0.3))
                        : null,
                  ),
                  child: Row(children: [
                    Icon(
                        sel ? item.activeIcon : item.icon,
                        size: 19,
                        color: sel
                            ? AppColors.accent
                            : AppColors.sidebarText
                                .withOpacity(0.6)),
                    const SizedBox(width: 11),
                    Text(item.label,
                        style: TextStyle(
                            color: sel
                                ? Colors.white
                                : AppColors.sidebarText
                                    .withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: sel
                                ? FontWeight.w600
                                : FontWeight.w400)),
                  ]),
                ),
              ),
            );
          }),

          const Spacer(),

          // 유저 정보 + 로그아웃
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  // 아바타
                  GestureDetector(
                    onTap: () => _showProfileDialog(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3B82F6),
                            Color(0xFF7C3AED)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showProfileDialog(context),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            userId.isNotEmpty
                                ? '@$userId'
                                : '',
                            style: TextStyle(
                              color: AppColors.sidebarText
                                  .withOpacity(0.5),
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 프로필 편집 버튼
                  GestureDetector(
                    onTap: () => _showProfileDialog(context),
                    child: Tooltip(
                      message: '프로필 편집',
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color:
                              AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color:
                              AppColors.accent.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // 로그아웃 버튼
                  GestureDetector(
                    onTap: onLogout,
                    child: Tooltip(
                      message: '로그아웃',
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.logout_rounded,
                          size: 14,
                          color: Colors.red.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 다크/라이트 토글
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 4),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (_, mode, __) {
                final isDark = mode == ThemeMode.dark;
                return GestureDetector(
                  onTap: themeNotifier.toggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withOpacity(0.07),
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(children: [
                      Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 16,
                        color: AppColors.sidebarText
                            .withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isDark ? '라이트 모드' : '다크 모드',
                        style: TextStyle(
                            color: AppColors.sidebarText
                                .withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 200),
                        width: 36,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.accent
                              : Colors.white.withOpacity(0.2),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: AnimatedAlign(
                          duration:
                              const Duration(milliseconds: 200),
                          alignment: isDark
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 2),
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              'Yu-Gi-Oh! Card Manager\nv1.4.0',
              style: TextStyle(
                  color:
                      AppColors.sidebarText.withOpacity(0.35),
                  fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 메인(홈) 화면 ─────────────────────────────────────────────
class _WelcomePage extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _WelcomePage({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bg(context);
    final txtPri = AppTheme.textPrimary(context);
    final txtSec = AppTheme.textSecondary(context);
    final surface = AppTheme.surface(context);
    final border = AppTheme.border(context);

    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email?.split('@').first ?? '사용자');

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF3B82F6),
                    Color(0xFF1D4ED8)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ],
              ),
              child: const Icon(Icons.style_rounded,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              '안녕하세요, $displayName님!',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: txtPri,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text('카드를 체계적으로 관리하세요',
                style: TextStyle(color: txtSec, fontSize: 15)),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QuickButton(
                    icon: Icons.style_rounded,
                    label: '카드 관리',
                    color: AppColors.monster,
                    bgColor: AppTheme.monsterBgAdaptive(context),
                    surface: surface,
                    border: border,
                    onTap: () => onNavigate(1)),
                const SizedBox(width: 16),
                _QuickButton(
                    icon: Icons.view_list_rounded,
                    label: '덱 관리',
                    color: AppColors.magic,
                    bgColor: AppTheme.magicBgAdaptive(context),
                    surface: surface,
                    border: border,
                    onTap: () => onNavigate(2)),
                const SizedBox(width: 16),
                _QuickButton(
                    icon: Icons.bar_chart_rounded,
                    label: '통계',
                    color: AppColors.accent,
                    bgColor: AppTheme.accentLightAdaptive(context),
                    surface: surface,
                    border: border,
                    onTap: () => onNavigate(3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color surface;
  final Color border;
  final VoidCallback onTap;

  const _QuickButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.surface,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final txtPri = AppTheme.textPrimary(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  color: txtPri,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}

// ── 프로필 편집 다이얼로그 ─────────────────────────────────────
void _showProfileDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const _ProfileDialog(),
  );
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog();

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _auth = AuthService();
  late final TextEditingController _nickCtrl;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _nickLoading = false;
  bool _passLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _nickMessage;
  bool _nickSuccess = false;
  String? _passMessage;
  bool _passSuccess = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? '';
    _nickCtrl = TextEditingController(text: name);
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateNickname() async {
    final newName = _nickCtrl.text.trim();
    if (newName.isEmpty) {
      setState(() {
        _nickMessage = '닉네임을 입력하세요';
        _nickSuccess = false;
      });
      return;
    }

    setState(() => _nickLoading = true);
    final result = await _auth.updateNickname(newName);
    setState(() {
      _nickLoading = false;
      _nickMessage = result;
      _nickSuccess = result == '닉네임이 변경되었습니다.';
    });
  }

  Future<void> _updatePassword() async {
    final currentPass = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (currentPass.isEmpty || newPass.isEmpty) {
      setState(() {
        _passMessage = '비밀번호를 입력하세요';
        _passSuccess = false;
      });
      return;
    }

    if (newPass != confirmPass) {
      setState(() {
        _passMessage = '새 비밀번호가 일치하지 않습니다.';
        _passSuccess = false;
      });
      return;
    }

    setState(() => _passLoading = true);
    final result = await _auth.updatePassword(currentPass, newPass);
    setState(() {
      _passLoading = false;
      _passMessage = result;
      _passSuccess = result == '비밀번호가 변경되었습니다.';
      if (_passSuccess) {
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bg(context);
    final surface = AppTheme.surface(context);
    final textPri = AppTheme.textPrimary(context);
    final textSec = AppTheme.textSecondary(context);
    final border = AppTheme.border(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '프로필 편집',
                style: TextStyle(
                  color: textPri,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),

              // 닉네임 섹션
              Text(
                '닉네임',
                style: TextStyle(
                  color: textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nickCtrl,
                style: TextStyle(color: textPri),
                decoration: InputDecoration(
                  hintText: '닉네임 입력',
                  hintStyle: TextStyle(color: textSec),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_nickMessage != null)
                Text(
                  _nickMessage!,
                  style: TextStyle(
                    color: _nickSuccess ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nickLoading ? null : _updateNickname,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                  ),
                  child: _nickLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          '닉네임 변경',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 28),

              // 비밀번호 섹션
              Text(
                '비밀번호 변경',
                style: TextStyle(
                  color: textPri,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _currentPassCtrl,
                obscureText: _obscureCurrent,
                style: TextStyle(color: textPri),
                decoration: InputDecoration(
                  hintText: '현재 비밀번호',
                  hintStyle: TextStyle(color: textSec),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: textSec,
                    ),
                    onPressed: () => setState(
                        () => _obscureCurrent = !_obscureCurrent),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newPassCtrl,
                obscureText: _obscureNew,
                style: TextStyle(color: textPri),
                decoration: InputDecoration(
                  hintText: '새 비밀번호',
                  hintStyle: TextStyle(color: textSec),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: textSec,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                style: TextStyle(color: textPri),
                decoration: InputDecoration(
                  hintText: '새 비밀번호 확인',
                  hintStyle: TextStyle(color: textSec),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: textSec,
                    ),
                    onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_passMessage != null)
                Text(
                  _passMessage!,
                  style: TextStyle(
                    color: _passSuccess ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _passLoading ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                  ),
                  child: _passLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          '비밀번호 변경',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
