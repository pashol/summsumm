import 'package:flutter_test/flutter_test.dart';
import 'package:summsumm/services/ai_service.dart';

void main() {
  group('AiService', () {
    late AiService service;

    setUp(() {
      service = AiService();
    });

    group('parseError', () {
      test('parses JSON error message', () {
        final result = service.parseError(
          401,
          '{"error": {"message": "Invalid API key"}}',
        );
        expect(result, 'Invalid API key');
      });

      test('returns status-code message for non-JSON body', () {
        final result = service.parseError(429, 'rate limit exceeded');
        expect(result, 'Rate limit exceeded (429)');
      });

      test('returns 401 message for empty body', () {
        final result = service.parseError(401, '');
        expect(result, 'Invalid API key (401)');
      });

      test('returns 403 message', () {
        final result = service.parseError(403, '');
        expect(result, 'Access denied (403)');
      });

      test('returns 500 message', () {
        final result = service.parseError(500, '');
        expect(result, 'Server error (500)');
      });

      test('returns generic message for unknown status', () {
        final result = service.parseError(418, '');
        expect(result, 'Request failed (418)');
      });
    });
  });

  group('AiException', () {
    test('toString returns message', () {
      const exception = AiException('test error');
      expect(exception.toString(), 'test error');
    });

    test('message is accessible', () {
      const exception = AiException('another error');
      expect(exception.message, 'another error');
    });
  });
}
