import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/models/answer_choice.dart';
import 'package:japan_driver/models/practice_draft.dart';
import 'package:japan_driver/models/practice_record.dart';
import 'package:japan_driver/models/progress_store.dart';
import 'package:japan_driver/models/question_comment.dart';

void main() {
  test('moves a question out of wrong review after a correct answer', () {
    final wrong = ProgressStore.empty().recordAnswer(
      questionId: '5536',
      selectedAnswer: AnswerChoice.circle,
      correctAnswer: AnswerChoice.cross,
      answeredAt: DateTime.utc(2026),
    );

    expect(wrong.wrongQuestionIds, contains('5536'));
    expect(wrong.wrongQuestionCount, 1);

    final corrected = wrong.recordAnswer(
      questionId: '5536',
      selectedAnswer: AnswerChoice.cross,
      correctAnswer: AnswerChoice.cross,
      answeredAt: DateTime.utc(2026, 1, 2),
    );

    expect(corrected.wrongQuestionIds, isNot(contains('5536')));
    expect(corrected.wrongQuestionCount, 0);
    expect(corrected.byQuestion['5536']?.attempts, 2);
    expect(corrected.byQuestion['5536']?.correctCount, 1);
    expect(corrected.byQuestion['5536']?.wrongCount, 1);
  });

  test('encodes and decodes persisted progress', () {
    final store = ProgressStore.empty().recordAnswer(
      questionId: 'ja-no-id',
      selectedAnswer: AnswerChoice.circle,
      correctAnswer: AnswerChoice.circle,
      answeredAt: DateTime.utc(2026),
    );

    final decoded = ProgressStore.decode(store.encode());

    expect(decoded.answeredQuestionCount, 1);
    expect(decoded.byQuestion['ja-no-id']?.lastAnswer, AnswerChoice.circle);
    expect(decoded.byQuestion['ja-no-id']?.lastWasCorrect, isTrue);
  });

  test('encodes and decodes saved practice drafts', () {
    final sessionId = practiceSessionId(
      bankId: 'karimen',
      mode: 'exam',
      workbookNumber: 1,
    );
    final store = ProgressStore.empty().saveDraft(
      PracticeDraft(
        sessionId: sessionId,
        currentIndex: 2,
        answers: {0: AnswerChoice.circle, 1: AnswerChoice.cross},
        savedAt: DateTime.utc(2026, 6, 30),
        remainingSeconds: 1725,
      ),
    );

    final decoded = ProgressStore.decode(store.encode());
    final draft = decoded.drafts[sessionId];

    expect(draft, isNotNull);
    expect(draft?.currentIndex, 2);
    expect(draft?.answers[0], AnswerChoice.circle);
    expect(draft?.answers[1], AnswerChoice.cross);
    expect(draft?.remainingSeconds, 1725);
  });

  test('encodes and decodes practice records', () {
    final store = ProgressStore.empty().addRecord(
      PracticeRecord(
        id: 'record-1',
        sessionId: 'karimen_test|exam|workbook:1',
        title: '仮免前',
        subtitle: 'テスト形式 / 第1回',
        mode: 'exam',
        completedAt: DateTime.utc(2026, 6, 30, 12, 30),
        answers: const [
          PracticeRecordAnswer(
            questionId: 'q1',
            selectedAnswer: AnswerChoice.circle,
            correctAnswer: AnswerChoice.circle,
          ),
          PracticeRecordAnswer(
            questionId: 'q2',
            selectedAnswer: AnswerChoice.circle,
            correctAnswer: AnswerChoice.cross,
          ),
        ],
      ),
    );

    final decoded = ProgressStore.decode(store.encode());
    final record = decoded.records.single;

    expect(record.id, 'record-1');
    expect(record.totalCount, 2);
    expect(record.correctCount, 1);
    expect(record.wrongCount, 1);
    expect(record.answers.last.correctAnswer, AnswerChoice.cross);
  });

  test('stores comments independently for each question', () {
    final store = ProgressStore.empty()
        .addComment(
          QuestionComment(
            id: 'comment-1',
            questionId: 'q1',
            text: '標識の位置に注意',
            authorLabel: 'テスト',
            createdAt: DateTime.utc(2026, 6, 30, 13),
          ),
        )
        .addComment(
          QuestionComment(
            id: 'comment-2',
            questionId: 'q2',
            text: '別の問題のコメント',
            authorLabel: 'ゲスト',
            createdAt: DateTime.utc(2026, 6, 30, 14),
          ),
        );

    final decoded = ProgressStore.decode(store.encode());

    expect(decoded.commentsByQuestion['q1']?.single.text, '標識の位置に注意');
    expect(decoded.commentsByQuestion['q2']?.single.id, 'comment-2');

    final removed = decoded.removeComment(
      questionId: 'q1',
      commentId: 'comment-1',
    );
    expect(removed.commentsByQuestion, isNot(contains('q1')));
    expect(removed.commentsByQuestion['q2'], hasLength(1));
  });

  test('stores favorites independently for each stage', () {
    final store = ProgressStore.empty()
        .toggleFavorite(stageId: 'karimen', questionId: 'q1')
        .toggleFavorite(stageId: 'sotsuken', questionId: 'q2');

    final decoded = ProgressStore.decode(store.encode());

    expect(decoded.favoritesForStage('karimen'), {'q1'});
    expect(decoded.favoritesForStage('sotsuken'), {'q2'});
    expect(
      decoded
          .toggleFavorite(stageId: 'karimen', questionId: 'q1')
          .favoritesForStage('karimen'),
      isEmpty,
    );
  });
}
