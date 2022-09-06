import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../data/constants.dart';

class ExclusaoMutuaClient {
  ExclusaoMutuaClient._();
  static final ExclusaoMutuaClient _instance = ExclusaoMutuaClient._();
  static ExclusaoMutuaClient get instance => _instance;

  Future<void> run({required String name}) async {
    late Socket socket;

    try {
      socket = await Socket.connect(host, port);
    } catch (e) {
      await run(name: name);
      return;
    }

    socket.write(name.isEmpty ? 'UNIX User' : name);

    socket.listen(
      (data) => _onData(socket, data),
      onError: (error) => _onError(socket, error),
      onDone: () => _onDone(socket, name),
    );

    final receive = ReceivePort();
    await Isolate.spawn(readMessages, receive.sendPort);
    await for (final message in receive) {
      sendMessage(socket, message);
    }
    socket.close();
  }

  void _onData(Socket socket, Uint8List data) {
    final serverResponse = utf8.decode(data);
    print(serverResponse);
  }

  void _onError(Socket socket, dynamic error) {
    socket.destroy();
    print(error);
  }

  void _onDone(Socket socket, String name) {
    socket.destroy();
    print('Server left.');
    run(name: name); // retry connection after server close or timeout
  }
}
