import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class _AuditOperation {
  final String category;
  final String action;
  final DateTime startTime;
  DateTime? endTime;

  _AuditOperation({
    required this.category,
    required this.action,
    required this.startTime,
  });

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
}

/// Registra eventos y errores de la app enviándolos a Sentry.
/// Si Sentry no está activo (sin DSN), vuelca todo a consola con [debugPrint].
class AppAuditLogger {
  AppAuditLogger._();

  static final AppAuditLogger instance = AppAuditLogger._();
  final Map<String, _AuditOperation> _pendingOps = {};

  bool get _sentryEnabled => Sentry.isEnabled;

  void _logStart(String module, String action, Map<String, dynamic>? data) {
    if (_sentryEnabled) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          type: 'default',
          category: module,
          message: '[START] $action',
          data: data ?? const {},
          level: SentryLevel.info,
        ),
      );
    }
    debugPrint('[$module][START] $action${data == null || data.isEmpty ? '' : ' | $data'}');
  }

  void _logEnd(
    String module,
    String action,
    int ms,
    String? result,
    Object? error,
    StackTrace? stack,
  ) {
    if (error != null) {
      if (_sentryEnabled) {
        Sentry.captureException(
          error,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('module', module);
            scope.setTag('action', action);
          },
        );
      }
      debugPrint('[$module][END] $action (${ms}ms)\n  ERROR: $error');
      return;
    }
    if (_sentryEnabled) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          type: 'default',
          category: module,
          message: '[END] $action (${ms}ms)',
          data: result == null ? const {} : {'result': result},
          level: SentryLevel.debug,
        ),
      );
    }
    debugPrint('[$module][END] $action (${ms}ms)${result == null ? '' : ' → $result'}');
  }

  /// Registra un evento puntual.
  void event(String module, String action,
      {Map<String, dynamic>? data, Object? error, StackTrace? stack}) {
    if (error != null) {
      if (_sentryEnabled) {
        Sentry.captureException(
          error,
          stackTrace: stack,
          withScope: (scope) {
            scope.setTag('module', module);
            scope.setTag('action', action);
            if (data != null) scope.setContexts('data', data);
          },
        );
      }
      debugPrint('[$module] $action | $data\n  ERROR: $error');
      return;
    }
    if (_sentryEnabled) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          type: 'default',
          category: module,
          message: action,
          data: data ?? const {},
        ),
      );
    }
    debugPrint('[$module] $action${data == null || data.isEmpty ? '' : ' | $data'}');
  }

  /// Inicia una operación con tracking de duración.
  /// Retorna un ID para llamar a [endOperation].
  String startOp(String module, String action,
      {Map<String, dynamic>? data}) {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${action.hashCode}';
    _logStart(module, action, data);
    _pendingOps[id] = _AuditOperation(
      category: module,
      action: action,
      startTime: DateTime.now(),
    );
    return id;
  }

  /// Finaliza una operación y registra su duración.
  void endOp(String id, {String? result, Object? error, StackTrace? stack}) {
    final op = _pendingOps.remove(id);
    final duration = op != null
        ? op.duration
        : const Duration(milliseconds: 0);
    final ms = duration.inMilliseconds;
    _logEnd(
      op?.category ?? '?',
      op?.action ?? '?',
      ms,
      result,
      error,
      stack,
    );
  }

  /// Registra inicio + fin de una operación síncrona simple.
  void trace(String module, String action,
      {Map<String, dynamic>? data,
      String? result,
      Object? error,
      StackTrace? stack}) {
    final id = startOp(module, action, data: data);
    endOp(id, result: result, error: error, stack: stack);
  }

  /// Registra un error/exception a Sentry (o consola si no hay DSN).
  void error(String module, Object error,
      {StackTrace? stack, Map<String, dynamic>? data}) {
    if (_sentryEnabled) {
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: (scope) {
          scope.setTag('module', module);
          if (data != null) scope.setContexts('data', data);
        },
      );
      return;
    }
    debugPrint('[$module] ERROR: $error');
    if (stack != null) debugPrint('  STACK: $stack');
  }

  /// Compatibilidad: ya no se escribe log físico. Retorna vacío.
  Future<String> read() async => '';

  /// Compatibilidad: ya no se escribe log físico.
  Future<String> get path async => '';

  /// Compatibilidad: ya no se escribe log físico.
  Future<void> clear() async {}
}