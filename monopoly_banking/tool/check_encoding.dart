// Guards the repo against text that was UTF-8 but got decoded as cp1252.
//
// Run directly:  dart run tool/check_encoding.dart
// Exits 1 and prints file:line for every hit, so it can gate a pre-commit hook.
//
// Design note: this only looks for the *lead* byte of a mangled sequence, and
// only for leads that cannot occur in this project's legitimate content.
// Deliberately narrow. A pre-commit guard that cries wolf teaches people to
// pass --no-verify, which makes the guard worthless; a missed exotic case is
// cheaper than that. It also flags invalid UTF-8, which is the other half of
// the failure mode (a cp1252 file decodes as UTF-8 only by accident).

import 'dart:convert';
import 'dart:io';

/// Codepoints that only appear when UTF-8 bytes are read as cp1252.
/// Not a single one of these occurs in normal Spanish/English source text,
/// which is what makes them safe to flag with no corroboration required.
const _mojibakeLeadCodepoints = <int>{
  0xC2, // A with circumflex
  0xC3, // A with tilde
  0xE2, // a with circumflex
  0xE3, // a with tilde
  0xF0, // eth: leads 4-byte sequences, e.g. emoji
};

const _maxFileBytes = 2 * 1024 * 1024;

Future<void> main(List<String> args) async {
  final files = _trackedFiles();
  if (files.isEmpty) {
    stderr.writeln('check_encoding: git ls-files returned nothing.');
    exit(2);
  }

  final findings = <String>[];
  var scanned = 0;
  var skippedBinary = 0;

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;

    final bytes = file.readAsBytesSync();
    if (bytes.length > _maxFileBytes || _looksBinary(bytes)) {
      skippedBinary++;
      continue;
    }
    scanned++;

    final relative = _relativeToRepoRoot(path);
    // Must be a real UTF-8 decode. String.fromCharCodes(bytes) would map each
    // byte to a code unit, i.e. decode UTF-8 as Latin-1, which turns every
    // legitimate non-ASCII character into its own mojibake signature and makes
    // this whole check report false positives on clean files.
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      findings.add('$relative: not valid UTF-8 (a cp1252 file is the usual cause)');
      continue;
    }

    for (final hit in _mojibakeHits(text)) {
      findings.add('$relative:${hit.line}: U+${hit.codepoint.toRadixString(16).toUpperCase().padLeft(4, '0')} in ${hit.context}');
    }
  }

  print('files scanned : $scanned');
  print('skipped binary/oversized : $skippedBinary');
  print('mojibake findings : ${findings.length}');

  if (findings.isEmpty) {
    print('OK: no mojibake found.');
    exit(0);
  }

  print('');
  for (final f in findings) {
    print('  $f');
  }
  print('');
  print('Text was UTF-8 read as cp1252. Fix the source, do not re-encode the file.');
  print('Do NOT use PowerShell Get-Content/Set-Content for UTF-8 source: it reads');
  print('as ANSI and double-encodes on write. Use the editor tooling instead.');
  exit(1);
}

/// Absolute paths of every tracked file, anchored to the repo root so this runs
/// identically from any subdirectory (the .gitignore at the root is the case
/// that must not be missed).
List<String> _trackedFiles() {
  final rootResult = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (rootResult.exitCode != 0) {
    stderr.writeln('check_encoding: not inside a git repository.');
    exit(2);
  }
  final root = (rootResult.stdout as String).trim();

  final result = Process.runSync(
    'git',
    ['ls-files', '-z'],
    workingDirectory: root,
    stdoutEncoding: null,
  );
  if (result.exitCode != 0) {
    stderr.writeln('check_encoding: git ls-files failed.');
    exit(2);
  }
  final out = (result.stdout as List).map((b) => b as int).toList();
  final separator = Platform.pathSeparator;
  return _splitNul(out)
      .where((p) => p.isNotEmpty)
      .map((p) => '$root${separator}${p.replaceAll('/', separator)}')
      .toList();
}

List<String> _splitNul(List<int> bytes) {
  final out = <String>[];
  var start = 0;
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] != 0) continue;
    out.add(utf8.decode(bytes.sublist(start, i), allowMalformed: true));
    start = i + 1;
  }
  if (start < bytes.length) {
    out.add(utf8.decode(bytes.sublist(start), allowMalformed: true));
  }
  return out;
}

bool _looksBinary(List<int> bytes) {
  final limit = bytes.length < 8000 ? bytes.length : 8000;
  for (var i = 0; i < limit; i++) {
    if (bytes[i] == 0) return true;
  }
  return false;
}

class _Hit {
  _Hit(this.line, this.codepoint, this.context);

  final int line;
  final int codepoint;
  final String context;
}

String _relativeToRepoRoot(String absolutePath) {
  final rootResult = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  final root = (rootResult.stdout as String).trim();
  final normalized = absolutePath.replaceAll('\\', '/');
  final normalizedRoot = root.replaceAll('\\', '/');
  if (normalized.startsWith(normalizedRoot)) {
    return normalized.substring(normalizedRoot.length + 1);
  }
  return absolutePath;
}

List<_Hit> _mojibakeHits(String text) {
  final hits = <_Hit>[];
  var line = 1;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x0A) {
      line++;
      continue;
    }
    if (!_mojibakeLeadCodepoints.contains(unit)) continue;

    final from = i > 24 ? i - 24 : 0;
    final to = i + 24 > text.length ? text.length : i + 24;
    final context = text
        .substring(from, to)
        .replaceAll('\n', r'\n')
        .replaceAll('\r', '');
    hits.add(_Hit(line, unit, '"$context"'));
  }
  return hits;
}