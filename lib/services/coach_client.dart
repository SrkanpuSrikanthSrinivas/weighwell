import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/exercise_catalog.dart';
import '../models/fitness.dart';
import '../models/models.dart';
import '../config.dart';
import 'auth_token.dart';

class CoachInsights {
  const CoachInsights({
    required this.headline,
    required this.score,
    required this.goingWell,
    required this.tryNext,
    required this.watchOut,
    required this.at,
  });
  final String headline;
  final int? score;
  final List<String> goingWell;
  final List<String> tryNext;
  final List<String> watchOut;
  final DateTime at;

  static List<String> _list(Object? v) => (v as List? ?? const []).whereType<String>().toList();

  factory CoachInsights.fromJson(Map<String, dynamic> j, DateTime at) => CoachInsights(
        headline: j['headline'] as String? ?? '',
        score: (j['score'] as num?)?.toInt(),
        goingWell: _list(j['goingWell']),
        tryNext: _list(j['tryNext']),
        watchOut: _list(j['watchOut']),
        at: at,
      );
}

class CoachPlan {
  const CoachPlan(this.plan, this.notes);
  final WeeklyPlan plan;
  final String notes;
}

/// Talks to backend/api/coach.js (address from lib/config.dart).
class CoachClient {
  CoachClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static String get base => AppConfig.api;

  bool get isConfigured => AppConfig.hasApi;

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    if (!isConfigured) throw StateError('AI coach is not set up in this build.');
    final res = await _client
        .post(Uri.parse('$base/coach'), headers: apiHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('Coach error ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<CoachInsights> insights(Map<String, dynamic> weekSummary) async {
    final j = await _post({'task': 'insights', 'summary': weekSummary});
    return CoachInsights.fromJson(j, DateTime.now());
  }

  Future<CoachPlan> suggestPlan({
    required Goal goal,
    required int daysPerWeek,
    required bool gym,
    required String level,
    required int minutes,
    required int age,
  }) async {
    final j = await _post({
      'task': 'plan',
      'goal': goal.name,
      'daysPerWeek': daysPerWeek,
      'place': gym ? 'gym' : 'home',
      'level': level,
      'minutes': minutes,
      'age': age,
      'exercises': exerciseCatalog.map((e) => e.name).toList(),
    });
    final plan = WeeklyPlan.fromJson((j['days'] as Map?)?.cast<String, dynamic>() ?? const {});
    return CoachPlan(plan, j['notes'] as String? ?? '');
  }
}
