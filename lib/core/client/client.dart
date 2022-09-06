import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../data/constants.dart';

class ExclusaoMutuaClient {
  ExclusaoMutuaClient._();
  static final ExclusaoMutuaClient _instance = ExclusaoMutuaClient._();
  static ExclusaoMutuaClient get instance => _instance;

  void run({required String name}) async {
    while (true) {
      final socket = await Socket.connect(host, port);

      socket.write(name.isEmpty ? 'UNIX User' : name);

      socket.listen(
        (data) {
          final serverResponse = utf8.decode(data);
          print(serverResponse);
        },
        onError: (error) {
          socket.destroy();
          print(error);
        },
        onDone: () {
          socket.destroy();
          print('Server left.');
          run(name: name);
        },
      );

      final receive = ReceivePort();
      await Isolate.spawn(readMessages, receive.sendPort);
      await for (final message in receive) {
        sendMessage(socket, message);
      }
      socket.close();
    }
  }
}
