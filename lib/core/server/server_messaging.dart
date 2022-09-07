import 'dart:collection';

import 'package:trabalho_01/data/constants.dart';
import 'package:trabalho_01/data/models/client_model.dart';

class ServerMessaging {
  final ListQueue<ClientModel> clients;

  ServerMessaging(this.clients);

  void messageAllUsers({required String message}) {
    for (final client in clients) {
      messageUser(client: client, message: message);
    }
  }

  void messageUser({required ClientModel client, required String message}) {
    client.connection.writeln(message);
  }

  void sendMessageToBoard({
    required String message,
    required ClientModel? clientWriter,
    required List<String> boardMessages,
    required void Function() onNext,
  }) {
    /// test if first in the QUEUE is the WRITER
    assert(clients.first == clientWriter);
    if (message == 'apagar' && boardMessages.isNotEmpty) {
      boardMessages.removeAt(0);
    } else {
      boardMessages.add(message);
    }
    onNext.call();
  }

  void sendRejectionMessage({required ClientModel client}) {
    /// PERFORMANCE ISSUE (convert structure to list to get INDEX)
    final queueIndex = clients.toList().indexOf(client);
    messageUser(
      client: client,
      message: 'Não é sua vez ainda! Aguarde! '
          '$queueIndex/${clients.length}',
    );
  }

  void warnMinimunClients() {
    final message = 'Aguardando clientes \n'
        '[${clients.length}/$minimumClientsBoard]';
    for (final client in clients) {
      client.connection.write(message);
    }
  }

  void drawBoard({required List<String> boardMessages}) {
    String message = '';
    for (final msg in boardMessages) {
      message += '$msg\n';
    }
    messageAllUsers(
      message: '---AVISOS---\n'
          '$message'
          '------------\n',
    );
  }
}
