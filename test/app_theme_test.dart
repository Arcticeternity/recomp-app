import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recomp_app/app_theme.dart';

void main() {
  test('预置 7 套主题', () {
    expect(appThemes.length, 7);
  });

  test('themeById 查找正确', () {
    final t = themeById('ocean');
    expect(t.label, '海洋蓝');
    expect(t.brightness, Brightness.light);
  });

  test('未知名返回默认（第一套）', () {
    expect(themeById('unknown').id, appThemes.first.id);
  });

  test('null 返回默认', () {
    expect(themeById(null).id, 'forest');
  });
}
