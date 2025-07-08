import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';
import 'package:lockity_flutter/repositories/locker_repository.dart';

class GetLockersUseCase {
  final LockerRepository _lockerRepository;

  const GetLockersUseCase(this._lockerRepository);

  Future<LockerListResponse> execute(LockerListRequest request) async {
    try {
      return await _lockerRepository.getLockers(request);
    } catch (e) {
      rethrow;
    }
  }
}