// Throwaway verification for TextRepair. Builds every fixture from codepoints so
// the assertions are independent of this file's own encoding.
import 'dart:io';

import '../lib/services/text_repair.dart';

String s(List<int> cps) => String.fromCharCodes(cps);

var failures = 0;

void check(String name, bool actual, bool expected) {
  final ok = actual == expected;
  if (!ok) failures++;
  print('${ok ? "PASS" : "FAIL"}  $name  (expected $expected, got $actual)');
}

void main() {
  print('=== must be detected as mojibake ===');
  // U+00C2 U+00B7 is the middot that rendered as "A with a circumflex".
  check('middot -> A-circumflex', TextRepair.hasMojibake(s([0xC2, 0xB7])), true);
  // U+1F464 (default avatar) after a cp1252 round trip.
  check(
    'default avatar corrupted',
    TextRepair.hasMojibake(s([0xF0, 0x178, 0x2018, 0xA4])),
    true,
  );
  // U+2192 (arrow) after a cp1252 round trip.
  check('arrow corrupted', TextRepair.hasMojibake(s([0xE2, 0x2020, 0x2019])), true);
  // U+00DA (U acute) after a latin-1 round trip.
  check('U-acute corrupted', TextRepair.hasMojibake(s([0xC3, 0x9A])), true);
  // U+1F525 (fire emoji) after a cp1252 round trip.
  check('fire emoji corrupted', TextRepair.hasMojibake(s([0xF0, 0x9F, 0x94, 0xA5])), true);

  print('');
  print('=== must NOT be flagged (real app content) ===');
  check('plain text', TextRepair.hasMojibake('Transferencia recibida'), false);
  check('empty string', TextRepair.hasMojibake(''), false);
  // Spanish letters that sit right next to the mojibake lead codepoints.
  check(
    'Spanish accents + n tilde + U acute',
    TextRepair.hasMojibake(s([0xDA, 0x6C, 0x74, 0x69, 0x6D, 0x61, 0x20]) +
        s([0xF1, 0x61, 0x6E, 0x64, 0xFA, 0x20, 0xBF, 0xA1, 0x20])),
    false,
  );
  check(
    'currency + separators',
    TextRepair.hasMojibake(s([0x20, 0x20AC, 0x20, 0xB7, 0x20, 0x2192, 0x20])),
    false,
  );
  check(
    'uppercase Spanish',
    TextRepair.hasMojibake(s([0xC1, 0x45, 0xCD, 0xD3, 0xDA, 0xD1, 0xFC])),
    false,
  );
  // Every avatar offered by the app.
  check(
    'valid avatar emojis',
    TextRepair.hasMojibake(
      s([0x1F3E6, 0x1F697, 0x1F415, 0x2693, 0x1F3B8, 0x1F462, 0x1F4B0, 0x26F5]),
    ),
    false,
  );

  print('');
  print('=== sanitize ===');
  final fallback = s([0x1F464]);
  check(
    'corrupt value is replaced',
    TextRepair.sanitize(s([0xF0, 0x178, 0x2018, 0xA4]), fallback: fallback) == fallback,
    true,
  );
  check(
    'valid value is preserved',
    TextRepair.sanitize(s([0x1F3E6]), fallback: fallback) == s([0x1F3E6]),
    true,
  );

  print('');
  if (failures == 0) {
    print('ALL CHECKS PASSED');
    exit(0);
  }
  print('$failures CHECK(S) FAILED');
  exit(1);
}