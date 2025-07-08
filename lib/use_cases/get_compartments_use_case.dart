import 'package:lockity_flutter/models/locker_response.dart';
import 'package:lockity_flutter/repositories/locker_repository.dart';

class GetCompartmentsUseCase {
  final LockerRepository _lockerRepository;

  const GetCompartmentsUseCase(this._lockerRepository);

  Future<CompartmentListResponse> execute(int lockerId) async {
    try {
      return await _lockerRepository.getCompartments(lockerId);
    } catch (e) {
      rethrow;
    }
  }
}