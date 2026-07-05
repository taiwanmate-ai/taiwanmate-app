import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final _pageController = PageController();
  int _currentPage = 0;

  // Step 1: Trình độ
  String? _level;
  // Step 2: Mục đích
  String? _purpose;
  // Step 3: User type
  String? _userType;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _fadeController.reset();
    _fadeController.forward();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await _storage.write(key: 'onboarding_done', value: 'true');
    await _storage.write(key: 'user_level', value: _level ?? 'beginner');
    await _storage.write(key: 'user_purpose', value: _purpose ?? 'general');
    await _storage.write(key: 'user_type', value: _userType ?? 'student');
    if (mounted) context.go('/home');
  }

  bool get _canNext {
    switch (_currentPage) {
      case 0: return _level != null;
      case 1: return _purpose != null;
      case 2: return _userType != null;
      default: return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _currentPage > 0 ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _currentPage--);
                    } : null,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: _currentPage > 0
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: List.generate(3, (i) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _currentPage
                                ? primary
                                : primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _finish,
                    child: Text('Bỏ qua',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 13,
                        )),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildLevelPage(),
                    _buildPurposePage(),
                    _buildUserTypePage(),
                  ],
                ),
              ),
            ),

            // Next button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: GestureDetector(
                onTap: _canNext ? _nextPage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: _canNext
                        ? LinearGradient(
                            colors: [primary, primary.withOpacity(0.7)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: _canNext ? null : primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _canNext
                        ? [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]
                        : [],
                  ),
                  child: Text(
                    _currentPage < 2 ? 'Tiếp theo →' : 'Bắt đầu học! 🚀',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _canNext ? Colors.white : primary.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Trình độ ──────────────────────────────────────
  Widget _buildLevelPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * 0.60,
      maxHeight: MediaQuery.of(context).size.height * 0.22,
    ),
    child: Image.asset('assets/images/Learning-bro.webp', fit: BoxFit.contain),
  ),
),
const SizedBox(height: 16),
const Text('Xin chào! 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Xin chào! 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Trình độ tiếng Trung của bạn hiện tại?',
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 32),
          ...[
            _LevelOption(
              emoji: '🌱',
              title: 'Mới bắt đầu',
              subtitle: 'Chưa biết gì hoặc mới học',
              value: 'beginner',
              selected: _level,
              onTap: (v) => setState(() => _level = v),
            ),
            _LevelOption(
              emoji: '📖',
              title: 'Cơ bản',
              subtitle: 'Biết chào hỏi, đếm số, từ đơn giản',
              value: 'basic',
              selected: _level,
              onTap: (v) => setState(() => _level = v),
            ),
            _LevelOption(
              emoji: '💬',
              title: 'Trung cấp',
              subtitle: 'Có thể giao tiếp đơn giản hàng ngày',
              value: 'intermediate',
              selected: _level,
              onTap: (v) => setState(() => _level = v),
            ),
            _LevelOption(
              emoji: '🎓',
              title: 'Nâng cao',
              subtitle: 'Giao tiếp tốt, muốn luyện thêm',
              value: 'advanced',
              selected: _level,
              onTap: (v) => setState(() => _level = v),
            ),
          ],
        ],
      ),
    );
  }

  // ── Page 2: Mục đích ──────────────────────────────────────
  Widget _buildPurposePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('Bạn học tiếng Trung để làm gì?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * 0.60,
      maxHeight: MediaQuery.of(context).size.height * 0.22,
    ),
    child: Image.asset('assets/images/Personal_goals-bro.webp', fit: BoxFit.contain),
  ),
),
const SizedBox(height: 16),
const Text('Bạn học tiếng Trung để làm gì?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Giúp AI cá nhân hóa nội dung cho bạn',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 32),
          ...[
            _PurposeOption(emoji: '💼', title: 'Làm việc tại Đài Loan', subtitle: 'Giao tiếp công sở, hợp đồng', value: 'work', selected: _purpose, onTap: (v) => setState(() => _purpose = v)),
            _PurposeOption(emoji: '🎓', title: 'Du học', subtitle: 'Học tại trường, làm bài tập', value: 'study', selected: _purpose, onTap: (v) => setState(() => _purpose = v)),
            _PurposeOption(emoji: '❤️', title: 'Gia đình / Kết hôn', subtitle: 'Nói chuyện với gia đình chồng/vợ', value: 'family', selected: _purpose, onTap: (v) => setState(() => _purpose = v)),
            _PurposeOption(emoji: '🌏', title: 'Du lịch', subtitle: 'Đi lại, mua sắm, ăn uống', value: 'travel', selected: _purpose, onTap: (v) => setState(() => _purpose = v)),
            _PurposeOption(emoji: '📜', title: 'Thi chứng chỉ TOCFL', subtitle: 'Luyện thi cấp độ A1-C1', value: 'tocfl', selected: _purpose, onTap: (v) => setState(() => _purpose = v)),
            _PurposeOption(emoji: '✨', title: 'Sở thích cá nhân', subtitle: 'Xem phim, nghe nhạc, đọc sách', value: 'hobby', selected: _purpose, onTap: (v) => setState(() => _purpose = v)),
          ],
        ],
      ),
    );
  }

  // ── Page 3: User type ─────────────────────────────────────
  Widget _buildUserTypePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('Bạn là ai?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * 0.60,
      maxHeight: MediaQuery.of(context).size.height * 0.22,
    ),
    child: Image.asset('assets/images/Community-rafiki.webp', fit: BoxFit.contain),
  ),
),
const SizedBox(height: 16),
const Text('Bạn là ai?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('AI sẽ điều chỉnh phong cách trò chuyện phù hợp',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 32),
          ...[
            _UserTypeCard(emoji: '🧒', title: 'Trẻ em', subtitle: 'Dưới 12 tuổi, học vui vẻ', value: 'kid', selected: _userType, onTap: (v) => setState(() => _userType = v)),
            _UserTypeCard(emoji: '🎓', title: 'Sinh viên', subtitle: 'AI thân thiện, chửi vui được!', value: 'student', selected: _userType, onTap: (v) => setState(() => _userType = v)),
            _UserTypeCard(emoji: '💼', title: 'Người đi làm', subtitle: 'Chuyên nghiệp, thực tế', value: 'adult', selected: _userType, onTap: (v) => setState(() => _userType = v)),
            _UserTypeCard(emoji: '👴', title: 'Người lớn tuổi', subtitle: 'Lịch sự, kiên nhẫn, từ tốn', value: 'elder', selected: _userType, onTap: (v) => setState(() => _userType = v)),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(
                'Bạn có thể thay đổi cài đặt này bất cứ lúc nào trong phần Chat → Settings',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), height: 1.5),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Option widgets ─────────────────────────────────────────
class _LevelOption extends StatelessWidget {
  final String emoji, title, subtitle, value;
  final String? selected;
  final Function(String) onTap;

  const _LevelOption({required this.emoji, required this.title, required this.subtitle, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.08) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primary : Theme.of(context).colorScheme.outline.withOpacity(0.15), width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isSelected ? primary : null)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ])),
          if (isSelected) Icon(Icons.check_circle_rounded, color: primary),
        ]),
      ),
    );
  }
}

class _PurposeOption extends StatelessWidget {
  final String emoji, title, subtitle, value;
  final String? selected;
  final Function(String) onTap;

  const _PurposeOption({required this.emoji, required this.title, required this.subtitle, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.08) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? primary : Theme.of(context).colorScheme.outline.withOpacity(0.15), width: isSelected ? 2 : 1),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? primary : null)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ])),
          if (isSelected) Icon(Icons.check_circle_rounded, color: primary, size: 20),
        ]),
      ),
    );
  }
}

class _UserTypeCard extends StatelessWidget {
  final String emoji, title, subtitle, value;
  final String? selected;
  final Function(String) onTap;

  const _UserTypeCard({required this.emoji, required this.title, required this.subtitle, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.08) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primary : Theme.of(context).colorScheme.outline.withOpacity(0.15), width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: primary.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? primary : null)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
          ])),
          if (isSelected) Icon(Icons.check_circle_rounded, color: primary),
        ]),
      ),
    );
  }
}
