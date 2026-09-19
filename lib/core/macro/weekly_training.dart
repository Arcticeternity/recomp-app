/// 每周训练时长，4 档。
enum WeeklyTraining {
  twoToThree('2-3小时/周'),
  fourToFive('4-5小时/周'),
  sixToSeven('6-7小时/周'),
  eightToNine('8-9小时/周');

  const WeeklyTraining(this.label);

  /// 面向用户的展示文案。
  final String label;
}
