import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/api_client.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/chatbot_button.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class ForecastingScreen extends StatefulWidget {
  const ForecastingScreen({super.key});

  @override
  State<ForecastingScreen> createState() => _ForecastingScreenState();
}

class _ForecastingScreenState extends State<ForecastingScreen> {
  final _apiClient = ApiClient();
  Map<String, dynamic>? _forecast;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.post(
        '/api/forecast',
        auth: true,
        body: {'days_ahead': 7},
      );
      setState(() {
        _forecast =
            (response['data'] as Map<String, dynamic>)['forecast']
                as Map<String, dynamic>;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();

    // Plan gate — forecasting requires Premium or Professional
    if (user.plan == 'free') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          title: Text(
            lang.t('forecast.title'),
            style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
          ),
        ),
        body: PlanGateBody(requiredPlan: 'premium', isRTL: lang.isRTL),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Transform.flip(
                            flipX: lang.isRTL,
                            child: const Icon(
                              Icons.arrow_back,
                              size: 28,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        lang.t('forecast.title'),
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _error != null
                      ? _errorView()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _currentRisk(lang),
                              const SizedBox(height: 24),
                              _riskTrend(lang),
                              const SizedBox(height: 24),
                              _peakAlert(lang),
                              const SizedBox(height: 24),
                              _recommendations(lang),
                              const SizedBox(height: 24),
                              _factors(lang),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            const ChatbotButton(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(active: 'home'),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error ?? 'Failed to load forecast',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadForecast,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentRisk(LanguageProvider lang) {
    final riskLevel = (_forecast?['risk_level']?.toString() ?? 'low')
        .toLowerCase();
    final color = riskLevel == 'high' || riskLevel == 'critical'
        ? const Color(0xFFF44336)
        : riskLevel == 'medium'
        ? const Color(0xFFFFC107)
        : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.t('forecast.currentRisk'),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const Icon(Icons.trending_up, color: Colors.white, size: 28),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _riskLabel(lang, riskLevel),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${((_forecast?['risk_score'] as num?)?.toDouble() ?? 0) * 100 ~/ 1}${lang.t('units.percent')} risk score',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskTrend(LanguageProvider lang) {
    final points =
        ((_forecast?['forecast'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>())
            .toList();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('forecast.riskTrend'),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CustomPaint(
              size: const Size(double.infinity, 200),
              painter: _AreaPainter(
                points
                    .map(
                      (point) =>
                          (((point['risk_score'] as num?)?.toDouble() ?? 0) *
                                  100)
                              .round(),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _peakAlert(LanguageProvider lang) {
    final points =
        ((_forecast?['forecast'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>())
            .toList();
    final peak = points.isEmpty
        ? null
        : points.reduce((current, next) {
            final currentRisk =
                (current['risk_score'] as num?)?.toDouble() ?? 0;
            final nextRisk = (next['risk_score'] as num?)?.toDouble() ?? 0;
            return nextRisk > currentRisk ? next : current;
          });
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFFFC107), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peak == null
                      ? 'No upcoming peak'
                      : 'Peak Risk: ${peak['day']}',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  peak == null
                      ? 'No strong risk spike detected in the current forecast window.'
                      : 'Risk rises to ${peak['risk_level']} with a score of ${(((peak['risk_score'] as num?)?.toDouble() ?? 0) * 100).round()}%.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendations(LanguageProvider lang) {
    final riskLevel = (_forecast?['risk_level']?.toString() ?? 'low')
        .toLowerCase();
    final steps = riskLevel == 'high' || riskLevel == 'critical'
        ? [
            [
              'Inspect the field',
              'Check affected zones today and isolate severe cases.',
            ],
            [
              'Prepare treatment',
              'Plan preventive or curative intervention before symptoms spread.',
            ],
            [
              'Reduce moisture',
              'Avoid long wet foliage periods and improve airflow.',
            ],
          ]
        : [
            [
              'Monitor closely',
              'Continue regular inspection of leaves and stems.',
            ],
            [
              'Keep records',
              'Track scan history and compare risk changes over time.',
            ],
            [
              'Maintain balance',
              'Keep irrigation and nutrition stable to reduce stress.',
            ],
          ];
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('disease.recommendedAction'),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map(
            (entry) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value[0],
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.value[1],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _factors(LanguageProvider lang) {
    final weatherImpact =
        (_forecast?['weather_impact'] as Map<String, dynamic>? ?? const {});
    final humidity =
        ((weatherImpact['humidity'] as num?)?.toDouble() ?? 0) / 100;
    final temp = ((weatherImpact['temperature'] as num?)?.toDouble() ?? 0) / 40;
    final wind = ((weatherImpact['wind_kmh'] as num?)?.toDouble() ?? 0) / 20;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contributing Factors',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _factorBar(
            lang.t('home.humidity'),
            '${(humidity * 100).round()}%',
            humidity,
          ),
          const SizedBox(height: 16),
          _factorBar(
            lang.t('home.temp'),
            '${(temp * 40).round()}${lang.t('units.celsius')}',
            temp,
          ),
          const SizedBox(height: 16),
          _factorBar(
            lang.t('home.wind'),
            '${(wind * 20).round()} ${lang.t('units.kmh')}',
            wind,
          ),
        ],
      ),
    );
  }

  Widget _factorBar(String label, String value, double progress) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            Text(value, style: const TextStyle(color: AppColors.primaryDark)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            backgroundColor: AppColors.background,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  String _riskLabel(LanguageProvider lang, String level) {
    switch (level) {
      case 'critical':
      case 'high':
        return lang.t('forecast.highRisk');
      case 'medium':
        return lang.t('forecast.moderateRisk');
      default:
        return lang.t('forecast.lowRisk');
    }
  }
}

class _AreaPainter extends CustomPainter {
  _AreaPainter(this.data);

  final List<int> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final linePaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xCCFFC107), Color(0x1AFFC107)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final path = Path();
    final fillPath = Path();
    for (int index = 0; index < data.length; index++) {
      final x = index * size.width / (data.length - 1);
      final y = size.height - (data[index] / 100) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
