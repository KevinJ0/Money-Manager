/// Detects text that was corrupted by a wrong-encoding round trip.
///
/// An older build of this app was saved with its Dart sources re-encoded through
/// cp1252. Every non-ASCII character became garbage that rendered as a stray
/// glyph next to the real text:
///
///   * U+00B7 MONGOLIAN VOWEL SEPARATOR (middle dot) -> U+00C2 U+00B7
///     which draws as "A with a circumflex" followed by a dot.
///   * U+1F464 BUST IN SILHOUETTE (default avatar)   -> U+00F0 U+0178 U+2018 U+00A4
///
/// Correcting the source strings did not clean up what that build already wrote
/// into Hive, because the corrupted bytes were persisted. This class is the
/// shared detector used by `DataRepairService` to tell stored garbage apart from
/// legitimate content.
class TextRepair {
  const TextRepair._();

  /// Codepoints that only ever show up as the leading byte of a mis-decoded
  /// multi-byte UTF-8 sequence.
  ///
  /// Characters this app legitimately stores are deliberately excluded, notably
  /// U+00C1 (A acute), U+00D1 (N tilde), U+20AC (euro sign), U+00B7 (middle
  /// dot), U+2192 (rightwards arrow), U+00E1 (a acute) and U+00F1 (n tilde), so
  /// Spanish names and labels are never mistaken for corruption.
  static const Set<int> _mojibakeLeadCodepoints = <int>{
    0x00C2, // A with circumflex
    0x00C3, // A with tilde
    0x00C5, // A with ring above
    0x00C6, // AE ligature
    0x00D0, // Eth
    0x00E2, // a with circumflex: leads the euro-sign garbage
    0x00F0, // d with stroke: leads the emoji garbage
    0x0153, // oe ligature
    0x0161, // s caron
    0x0178, // Y with diaeresis: tail of the emoji garbage
    0x017E, // z caron
    0x0192, // f with hook
    0x02C6, // modifier letter circumflex accent
    0x02DC, // small tilde
    0x201A, // single low-9 quotation mark
    0x201E, // double low-9 quotation mark
    0x2030, // per mille sign
  };

  /// Whether [value] carries the fingerprint of a wrong-encoding round trip.
  static bool hasMojibake(String value) =>
      value.runes.any(_mojibakeLeadCodepoints.contains);

  /// Returns [fallback] when [value] is corrupted, otherwise [value] unchanged.
  ///
  /// The corrupted value is discarded rather than decoded back, because undoing
  /// the round trip requires guessing which of the several legacy code pages was
  /// used, and a wrong guess reintroduces garbage.
  static String sanitize(String value, {required String fallback}) =>
      hasMojibake(value) ? fallback : value;
}