import 'package:lockity_flutter/models/locker_config_response.dart';
import 'package:lockity_flutter/models/locker_request.dart';
import 'package:lockity_flutter/models/locker_response.dart';

abstract class LockerRepository {
  Future<LockerListResponse> getLockers(LockerListRequest request);
  Future<LockerOperationResponse> updateLockerStatus(UpdateLockerStatusRequest request);
  Future<LockerConfigResponse> getLockerConfig(String serialNumber);
}