import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const YouTubeTrackerApp());

class YouTubeTrackerApp extends StatelessWidget {
  const YouTubeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YouTube Tracker',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF1635)),
      ),
      home: const TrackerShell(),
    );
  }
}

const red = Color(0xFFFF1735);
const dark = Color(0xFF101426);
const muted = Color(0xFF66708D);
const pageBg = Color(0xFFF8F8FC);


class YouTubeUsageService {
  static const MethodChannel _channel =
      MethodChannel('youtube_tracker/usage');

  static Future<Map<dynamic, dynamic>> getUsage() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getUsageSummary',
    );
    return result ?? {};
  }

  static Future<void> openUsageSettings() async {
    await _channel.invokeMethod('openUsageAccessSettings');
  }
}

String formatUsage(int milliseconds) {
  final totalMinutes = milliseconds ~/ 60000;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}

class TrackerShell extends StatefulWidget {
  const TrackerShell({super.key});

  @override
  State<TrackerShell> createState() => _TrackerShellState();
}

class _TrackerShellState extends State<TrackerShell> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: const [DashboardScreen(), DetailsScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE8EC),
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: red),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: red),
            label: 'Details',
          ),
        ],
      ),
    );
  }
}


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {

  Map<dynamic, dynamic> usage = {};
  bool loading = true;
  bool hasPermission = false;
  String? error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    loadUsage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadUsage();
    }
  }

  Future<void> loadUsage() async {
    try {
      final data = await YouTubeUsageService.getUsage();

      if (!mounted) return;

      setState(() {
        usage = data;
        hasPermission = data['hasPermission'] == true;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> enableUsageAccess() async {
    await YouTubeUsageService.openUsageSettings();
  }

  int get today => (usage['todayMillis'] as num?)?.toInt() ?? 0;

  int get week => (usage['weekMillis'] as num?)?.toInt() ?? 0;

  int get month => (usage['monthMillis'] as num?)?.toInt() ?? 0;

  int get average =>
      (usage['dailyAverageMillis'] as num?)?.toInt() ?? 0;

  List<int> get weeklyValues {
    final raw = usage['lastSevenDaysMillis'] as List?;

    if (raw == null) return List.filled(7, 0);

    return raw.map((e) => (e as num).toInt()).toList();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && usage.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: red),
      );
    }

    if (!hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                size: 55,
                color: red,
              ),
              const SizedBox(height: 15),
              const Text(
                'Enable Usage Access',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: dark,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Allow YouTube Tracker to read app usage '
                'statistics to display your daily YouTube usage.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: enableUsageAccess,
                style: FilledButton.styleFrom(
                  backgroundColor: red,
                ),
                child: const Text('Enable Usage Access'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadUsage,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        children: [
          const _BrandHeader(),
          const SizedBox(height: 22),

          _TodayUsageCard(
            usageText: formatUsage(today),
          ),

          const SizedBox(height: 16),

          _SummaryStats(
            week: formatUsage(week),
            month: formatUsage(month),
            average: formatUsage(average),
          ),

          const SizedBox(height: 16),

          _UsageTrendCard(
            values: weeklyValues,
          ),

          const SizedBox(height: 16),

          _InsightCard(
            title: 'YouTube Usage',
            message: error == null
                ? 'Your dashboard is showing your actual YouTube app usage.'
                : 'Unable to refresh usage data: $error',
            icon: Icons.insights_rounded,
            background: const Color(0xFFFFE9ED),
            iconColor: red,
          ),
        ],
      ),
    );
  }
}


class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      children: const [
        _DetailsHeader(),
        SizedBox(height: 22),
        _PeriodSelector(),
        SizedBox(height: 18),
        _TotalUsageCard(),
        SizedBox(height: 16),
        _ComparisonCard(),
        SizedBox(height: 16),
        _BreakdownCard(),
        SizedBox(height: 16),
        _InsightCard(
          title: 'Insights',
          message: 'You spent 38% of your YouTube time on Shorts this month.',
          icon: Icons.lightbulb_outline_rounded,
          background: Color(0xFFFFF0E7),
          iconColor: Color(0xFFFF8A00),
          leadingIcon: Icons.star_rounded,
        ),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 42,
          decoration: BoxDecoration(
            color: red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 34),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YouTube Tracker',
                  style: TextStyle(
                      color: dark, fontSize: 21, fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text('Know your usage. Take control.',
                  style: TextStyle(color: muted, fontSize: 13)),
            ],
          ),
        ),
        _CircleIcon(icon: Icons.settings_outlined),
      ],
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.arrow_back_ios_new_rounded, color: dark, size: 20),
        const Expanded(
          child: Center(
            child: Text('Details',
                style: TextStyle(
                    color: dark, fontSize: 21, fontWeight: FontWeight.w800)),
          ),
        ),
        const _CircleIcon(icon: Icons.calendar_month_outlined),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  const _CircleIcon({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
            color: Color(0xFFF0F1F8), shape: BoxShape.circle),
        child: Icon(icon, color: dark, size: 22),
      );
}

class _TodayUsageCard extends StatelessWidget {
  final String usageText;

  const _TodayUsageCard({
    required this.usageText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF1735), Color(0xFFFF6D79)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
              color: red.withOpacity(.16),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Usage",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(usageText,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          height: 1)),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.south_rounded,
                        color: Color(0xFFB9FFE2), size: 21),
                    SizedBox(width: 5),
                    Text('32%',
                        style: TextStyle(
                            color: Color(0xFFB9FFE2),
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    SizedBox(width: 9),
                    Text('vs yesterday',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.20),
                shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 55),
          ),
        ],
      ),
    );
  }
}

class _SummaryStats extends StatelessWidget {
  const _SummaryStats();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 8),
      child: Row(
        children: const [
          Expanded(
              child: _StatItem(
                  icon: Icons.calendar_month_outlined,
                  color: Color(0xFF2585F5),
                  label: 'This Week',
                  value: '12h 24m')),
          _VerticalDivider(),
          Expanded(
              child: _StatItem(
                  icon: Icons.access_time_rounded,
                  color: Color(0xFF8056E8),
                  label: 'This Month',
                  value: '48h 16m')),
          _VerticalDivider(),
          Expanded(
              child: _StatItem(
                  icon: Icons.bar_chart_rounded,
                  color: Color(0xFF12A77A),
                  label: 'Daily Avg',
                  value: '1h 46m')),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatItem(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration:
              BoxDecoration(color: color.withOpacity(.11), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 9),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(
                  color: dark, fontSize: 14, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 88, color: const Color(0xFFE9EAF1));
}

class _UsageTrendCard extends StatelessWidget {
  final List<int> values;

  const _UsageTrendCard({
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.fromLTRB(17, 18, 17, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: dark, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Usage Trend',
                    style: TextStyle(
                        color: dark, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EF)),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  children: [
                    Text('7 Days',
                        style: TextStyle(
                            color: dark, fontWeight: FontWeight.w600)),
                    SizedBox(width: 7),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 205, child: WeeklyBarChart(valuesMillis: values)),
        ],
      ),
    );
  }
}


class WeeklyBarChart extends StatelessWidget {
  final List<int> valuesMillis;

  const WeeklyBarChart({
    super.key,
    required this.valuesMillis,
  });

  @override
  Widget build(BuildContext context) {
    final values = valuesMillis
        .map((v) => v / 3600000)
        .toList();

    const labels = [
      '6d ago',
      '5d ago',
      '4d ago',
      '3d ago',
      '2d ago',
      'Yesterday',
      'Today',
    ];

    final maxValue = values.fold<double>(
      1,
      (a, b) => a > b ? a : b,
    );

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final height = values[i] == 0
                  ? 2.0
                  : (values[i] / maxValue) * 125;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (i == 6 && values[i] > 0)
                        Text(
                          formatUsage(valuesMillis[i]),
                          style: const TextStyle(
                            color: red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 7),
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: i == 6
                              ? red
                              : const Color(0xFFFFA0AA),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(
            7,
            (i) => Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: muted,
                  fontSize: 9,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class _PeriodSelector extends StatefulWidget {
  const _PeriodSelector();

  @override
  State<_PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<_PeriodSelector> {
  int selected = 1;
  final options = const ['7 Days', '30 Days', '3 Months', 'Custom'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (index) {
        final active = selected == index;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() => selected = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: active ? red : const Color(0xFFEDEEF5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(options[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: active ? Colors.white : dark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TotalUsageCard extends StatelessWidget {
  const _TotalUsageCard();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time_rounded, color: red, size: 21),
              SizedBox(width: 9),
              Text('Total YouTube Usage',
                  style: TextStyle(
                      color: dark, fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('48h 16m',
                          style: TextStyle(
                              color: dark,
                              fontSize: 43,
                              fontWeight: FontWeight.w800,
                              height: 1.1)),
                    ),
                    SizedBox(height: 8),
                    Text('≈ 1h 36m per day',
                        style: TextStyle(
                            color: muted,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                width: 105,
                height: 105,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFE8EC), shape: BoxShape.circle),
                child: const Icon(Icons.access_time_filled_rounded,
                    color: red, size: 53),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      color: const Color(0xFFFFF1F3),
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 12),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_up_rounded, color: red, size: 23),
                    SizedBox(width: 7),
                    Text('12%',
                        style: TextStyle(
                            color: red,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                SizedBox(height: 4),
                Text('vs previous 30 days',
                    style: TextStyle(color: muted, fontSize: 11)),
              ],
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.smart_display_rounded, color: red, size: 22),
                    SizedBox(width: 6),
                    Text('~ 72 videos',
                        style: TextStyle(
                            color: dark,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                SizedBox(height: 4),
                Text('watched',
                    style: TextStyle(color: muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: red, size: 22),
              SizedBox(width: 9),
              Text('Usage Breakdown',
                  style: TextStyle(
                      color: dark, fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              const Expanded(
                flex: 5,
                child: Center(
                  child: SizedBox(
                    width: 158,
                    height: 158,
                    child: CustomPaint(
                      painter: _DonutPainter(),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('48h 16m',
                                style: TextStyle(
                                    color: dark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            Text('Total',
                                style: TextStyle(color: muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _LegendRow(
                        color: red, label: 'Shorts', percentage: '38%'),
                    SizedBox(height: 22),
                    _LegendRow(
                        color: Color(0xFFFF8A91),
                        label: 'Regular Videos',
                        percentage: '62%'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 27
      ..strokeCap = StrokeCap.butt;
    paint.color = const Color(0xFFFF8A91);
    canvas.drawArc(rect.deflate(14), -1.5708, 6.2832 * .62, false, paint);
    paint.color = red;
    canvas.drawArc(
        rect.deflate(14), -1.5708 + 6.2832 * .62, 6.2832 * .38, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String percentage;

  const _LegendRow(
      {required this.color, required this.label, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(
            child: Text(label,
                style: const TextStyle(color: dark, fontSize: 11))),
        Text(percentage,
            style: const TextStyle(
                color: dark, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color background;
  final Color iconColor;
  final IconData? leadingIcon;

  const _InsightCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.background,
    required this.iconColor,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.55), shape: BoxShape.circle),
            child: Icon(leadingIcon ?? icon, color: iconColor, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: iconColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(message,
                    style: const TextStyle(
                        color: dark, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF987C80), size: 25),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF26304D).withOpacity(.045),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: child,
    );
  }
}
