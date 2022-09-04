import 'dart:io';

class ClientModel {
  final Socket connection;
  String? name;

  ClientModel({required this.connection});
}
