import 'dart:io';
import 'dart:isolate';

const host = '127.0.0.1';
const port = 28960;

void sendMessage(Socket socket, String? message) {
  if (message != null) socket.write(message);
}

void readMessages(SendPort port) {
  String message = '';
  while (message != 'exit') {
    message = stdin.readLineSync() ?? '';
    port.send(message);
  }
  Isolate.exit(port);
}
