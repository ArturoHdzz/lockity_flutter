import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';
import 'package:lockity_flutter/repositories/locker_repository.dart';

class GetLockersUseCase {
  final LockerRepository repository;

  const GetLockersUseCase(this.repository);

  Future<LockerListResponse> execute(LockerListRequest request) async {
    try {
      return await repository.getLockers(request);
    } catch (e) {
      rethrow;
    }
  }
}