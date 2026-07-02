import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:japan_driver/models/answer_choice.dart';
import 'package:japan_driver/models/progress_store.dart';
import 'package:japan_driver/repositories/progress_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads server progress with a Firebase bearer token', () async {
    final expected = ProgressStore.empty().recordAnswer(
      questionId: 'q1',
      selectedAnswer: AnswerChoice.circle,
      correctAnswer: AnswerChoice.circle,
    );
    final repository = ProgressRepository(
      apiBaseUrl: 'https://example.com/v1',
      idTokenProvider: ({bool forceRefresh = false}) async => 'token-1',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://example.com/v1/progress');
        expect(request.headers['authorization'], 'Bearer token-1');
        return http.Response(
          jsonEncode({'data': expected.toJson()}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final loaded = await repository.load('untrusted-client-uid');

    expect(loaded.byQuestion['q1']?.lastWasCorrect, isTrue);
  });

  test(
    'refreshes the Firebase token once after an unauthorized response',
    () async {
      final tokenRequests = <bool>[];
      var apiRequests = 0;
      final repository = ProgressRepository(
        apiBaseUrl: 'https://example.com/v1',
        idTokenProvider: ({bool forceRefresh = false}) async {
          tokenRequests.add(forceRefresh);
          return forceRefresh ? 'fresh-token' : 'stale-token';
        },
        client: MockClient((request) async {
          apiRequests += 1;
          if (apiRequests == 1) {
            expect(request.headers['authorization'], 'Bearer stale-token');
            return http.Response('{}', 401);
          }
          expect(request.headers['authorization'], 'Bearer fresh-token');
          return http.Response(
            jsonEncode({'data': ProgressStore.empty().toJson()}),
            200,
          );
        }),
      );

      await repository.load('client-uid');

      expect(tokenRequests, [false, true]);
      expect(apiRequests, 2);
    },
  );

  test('migrates legacy local progress when the server has no data', () async {
    final local = ProgressStore.empty().toggleFavorite(
      stageId: 'karimen',
      questionId: 'q1',
    );
    SharedPreferences.setMockInitialValues({
      '${ProgressRepository.legacyStorageKey}:user:firebase-uid': local
          .encode(),
    });
    var apiRequests = 0;
    final repository = ProgressRepository(
      apiBaseUrl: 'https://example.com/v1',
      idTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        apiRequests += 1;
        if (request.method == 'GET') {
          return http.Response('{}', 404);
        }
        final payload = jsonDecode(request.body) as Map<String, Object?>;
        final data = payload['data'] as Map<String, Object?>;
        expect((data['favorites'] as Map)['karimen'], contains('q1'));
        return http.Response('{}', 200);
      }),
    );

    final loaded = await repository.load('firebase-uid');
    final prefs = await SharedPreferences.getInstance();

    expect(loaded.favoritesForStage('karimen'), {'q1'});
    expect(apiRequests, 2);
    expect(
      prefs.getString(
        '${ProgressRepository.legacyStorageKey}:user:firebase-uid',
      ),
      isNull,
    );
  });
}
