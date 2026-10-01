import 'package:money_manager/core/constants.dart';
import 'package:money_manager/services/app_audit_logger.dart';
import 'package:money_manager/services/bank_ledger_service.dart';
import 'package:money_manager/services/hive_service.dart';
import 'package:money_manager/services/text_repair.dart';

/// One-shot cleanup of values that a mis-encoded build persisted into Hive.
///
/// Fixing the corrupted source strings in `fc50e60` stopped new garbage from being
/// written, but every avatar stored while that build was in circulation kept the
/// corrupted bytes on the device, so they still render as unreadable glyphs.
/// This runs on every startup and is a no-op once the data is clean, costing a
/// single pass over one session record plus the bank account map.
class DataRepairService {
  const DataRepairService._();

  static const _sessionKey = 'current';

  /// Repairs every known corrupted field. Never throws: a failed repair must not
  /// stop the app from launching, so failures are reported to the audit log.
  static Future<void> run() async {
    try {
      final repaired = <String, int>{
        'session_avatar': await _repairSessionAvatar(),
        'bank_avatars': await BankLedgerService().repairCorruptedAvatars(),
      }..removeWhere((_, count) => count == 0);

      if (repaired.isEmpty) return;
      AppAuditLogger.instance.event(
        'REPAIR',
        'mojibake_fields_reset',
        data: repaired,
      );
    } catch (e, stack) {
      AppAuditLogger.instance.error('REPAIR', e, stack: stack);
    }
  }

  static Future<int> _repairSessionAvatar() async {
    final session = HiveService.sessionBox.get(_sessionKey);
    if (session == null || !TextRepair.hasMojibake(session.avatarId)) return 0;

    session.avatarId = kDefaultAvatar;
    await HiveService.sessionBox.put(_sessionKey, session);
    return 1;
  }
}