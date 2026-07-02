const _guestOneToOneBankIds = {'karimen_1to1', 'sotsuken_1to1'};

bool canGuestStartPractice({
  required String bankId,
  required bool isInstantFeedback,
  required int? workbookNumber,
  required int? chapterNumber,
  required int? rangeStep,
}) {
  return _guestOneToOneBankIds.contains(bankId) &&
      isInstantFeedback &&
      workbookNumber == 1 &&
      chapterNumber == null &&
      rangeStep == null;
}
