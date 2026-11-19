import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  /// null when the request never got an HTTP response (offline / network error).
  final int? statusCode;
  const ServerFailure({required super.message, this.statusCode});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}
