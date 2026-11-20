import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../domain/where_am_i.dart';

part 'home_service.g.dart';

/// The home screen's public numbers, asked without logging in (the server's
/// online count takes no `Authorization` header).
class HomeService {
  HomeService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /stats/online/: "{n} at tables".
  Future<OnlineStats> fetchOnline() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/stats/online/',
      );
      return OnlineStats.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

@riverpod
HomeService homeService(Ref ref) =>
    HomeService(client: ref.watch(apiClientProvider));
