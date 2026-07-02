import 'package:flutter_test/flutter_test.dart';
import 'package:japan_driver/account_access.dart';

void main() {
  test('guest can start only the first one-to-one workbook for each stage', () {
    for (final bankId in ['karimen_1to1', 'sotsuken_1to1']) {
      expect(
        canGuestStartPractice(
          bankId: bankId,
          isInstantFeedback: true,
          workbookNumber: 1,
          chapterNumber: null,
          rangeStep: null,
        ),
        isTrue,
      );
    }
  });

  test('guest cannot bypass the practice restriction', () {
    expect(
      canGuestStartPractice(
        bankId: 'karimen_1to1',
        isInstantFeedback: true,
        workbookNumber: 2,
        chapterNumber: null,
        rangeStep: null,
      ),
      isFalse,
    );
    expect(
      canGuestStartPractice(
        bankId: 'karimen_test',
        isInstantFeedback: false,
        workbookNumber: 1,
        chapterNumber: null,
        rangeStep: null,
      ),
      isFalse,
    );
    expect(
      canGuestStartPractice(
        bankId: 'curriculum_stage1',
        isInstantFeedback: true,
        workbookNumber: null,
        chapterNumber: 1,
        rangeStep: null,
      ),
      isFalse,
    );
    expect(
      canGuestStartPractice(
        bankId: 'sotsuken_1to1',
        isInstantFeedback: true,
        workbookNumber: null,
        chapterNumber: null,
        rangeStep: null,
      ),
      isFalse,
    );
  });
}
