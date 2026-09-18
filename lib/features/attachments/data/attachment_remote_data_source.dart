import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

/// Thin wrapper over the nested `Api\V1\{Note,Reminder}AttachmentController`
/// routes — there is no list endpoint (attachments are only ever exposed
/// nested inside a note/reminder's own resource), only create/download/
/// delete scoped to a parent.
class AttachmentRemoteDataSource {
  AttachmentRemoteDataSource(this._api);

  final ApiClient _api;

  String _basePath(String attachableType, String parentServerUuid) =>
      attachableType == 'note'
      ? '/notes/$parentServerUuid/attachments'
      : '/reminders/$parentServerUuid/attachments';

  Future<Map<String, dynamic>> create({
    required String attachableType,
    required String parentServerUuid,
    required String filePath,
    required String filename,
  }) async {
    final body = await _api.post(
      _basePath(attachableType, parentServerUuid),
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      }),
    );

    return body['data'] as Map<String, dynamic>;
  }

  Future<List<int>> download({
    required String attachableType,
    required String parentServerUuid,
    required String attachmentServerUuid,
  }) => _api.downloadBytes(
    '${_basePath(attachableType, parentServerUuid)}/$attachmentServerUuid',
  );

  Future<void> delete({
    required String attachableType,
    required String parentServerUuid,
    required String attachmentServerUuid,
  }) => _api.delete(
    '${_basePath(attachableType, parentServerUuid)}/$attachmentServerUuid',
  );
}
