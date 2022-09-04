import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'constants.dart';

class ExclusaoMutuaClient {
  ExclusaoMutuaClient._();
  static final ExclusaoMutuaClient _instance = ExclusaoMutuaClient._();
  static ExclusaoMutuaClient get instance => _instance;

  void run({required String name}) async {
    final socket = await Socket.connect(host, port);

    socket.write(name.isEmpty ? 'UNIX User' : name);

    socket.listen(
      (data) => _onData(socket, data),
      onError: (error) => _onError(socket, error),
      onDone: () => _onDone(socket),
    );

    final receive = ReceivePort();
    await Isolate.spawn(readMessages, receive.sendPort);
    await for (final message in receive) {
      sendMessage(socket, message);
    }
    socket.close();
  }

  void _onData(Socket socket, Uint8List data) {
    final serverResponse = String.fromCharCodes(data);
    print(serverResponse);
  }

  void _onError(Socket socket, dynamic error) {
    socket.destroy();
    print(error);
  }

  void _onDone(Socket socket) {
    socket.destroy();
    print('Server left.');
  }
}
