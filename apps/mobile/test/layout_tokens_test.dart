import 'package:flutter_test/flutter_test.dart';

import 'package:fichar_mobile/theme/layout_tokens.dart';

void main() {
  test('kContentMaxWidthForm is 440', () {
    expect(kContentMaxWidthForm, 440);
  });

  test('kContentMaxWidthFormWide is 560', () {
    expect(kContentMaxWidthFormWide, 560);
  });

  test('kBreakpointTablet is 600', () {
    expect(kBreakpointTablet, 600);
  });
}
