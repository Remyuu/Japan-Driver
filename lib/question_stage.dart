import 'models/question_bank.dart';

String? questionStageId(DriverQuestion question) {
  return switch (question.bankId) {
    'karimen_1to1' || 'karimen_test' || 'curriculum_stage1' => 'karimen',
    'sotsuken_1to1' || 'sotsuken_test' || 'curriculum_stage2' => 'sotsuken',
    'difficult' => switch (question.rangeStep) {
      1 => 'karimen',
      2 => 'sotsuken',
      _ => null,
    },
    _ => null,
  };
}
