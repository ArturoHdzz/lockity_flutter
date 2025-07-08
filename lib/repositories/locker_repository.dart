import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';

abstract class LockerRepository {
  Future<LockerListResponse> getLockers(LockerListRequest request);
  Future<CompartmentListResponse> getCompartments(int lockerId);
  Future<LockerOperationResponse> updateLockerStatus(UpdateLockerStatusRequest request);
}