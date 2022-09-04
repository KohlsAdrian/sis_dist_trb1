import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:trabalho_01/models/client_model.dart';

import 'constants.dart';

class ExclusaoMutuaServer {
  ExclusaoMutuaServer._();
  static final ExclusaoMutuaServer _instance = ExclusaoMutuaServer._();
  static ExclusaoMutuaServer get instance => _instance;

  ClientModel? _currentClientWriter;

  final _minClients = 1; // minimum clients to start using board

  final _clients = ListQueue<ClientModel>(); // clients FIFO
  int get _clientsLength => _clients.length;

  final _boardMessages = <String>[];

  void run() async {
    final server = await ServerSocket.bind(host, port);
    server.listen(_onClientConnect);
  }

  void _onClientConnect(Socket connection) {
    final client = ClientModel(connection: connection);

    // first client always the main WRITER
    if (_clients.isEmpty) _currentClientWriter = client;

    _clients.add(client); // new connection = end at the queue

    client.connection.listen(
      (data) => _onClientEvent(data, client),
      onDone: () => _onClientDone(client),
      onError: (error) => _onClientError(error, client),
    );
  }

  /* ||||||||||||||||||||||||||||||| */

  /* START OF MESSAGING */
  void _messageAllUsers({required String message}) {
    for (final client in _clients) {
      client.connection.write(message);
    }
  }

  void _messageUser({
    required ClientModel client,
    required String message,
  }) {
    client.connection.write(message);
  }

  void _onSendMessageToBoard({required String message}) {
    // test if first in the QUEUE is the WRITER
    assert(_clients.first == _currentClientWriter);
    _boardMessages.add(message);
    _onNextQueue();
  }

  void _onSendRejection({required ClientModel client}) {
    final queueIndex = _clients.toList().indexOf(client); // performance issue
    _messageUser(
      client: client,
      message: 'Não é sua vez ainda! Aguarde! $queueIndex/$_clientsLength',
    );
  }

  void _onWarnMinimunClients() {
    final message = 'Aguardando clientes [$_clientsLength/$_minClients]';
    print(message);
    for (final client in _clients) {
      client.connection.write(message);
    }
  }

  /* END OF MESSAGING */

  /* ||||||||||||||||||||||||||||||| */

  /* START OF USE CASE */

  void _onNextQueue() {
    ClientModel client = _clients.removeFirst(); // remove first in QUEUE
    _clients.add(client); // add to end of QUEUE

    _messageUser(
      client: client,
      message: 'Você foi colocado no final da fila!\n',
    );

    _currentClientWriter = _clients.first;
    _messageUser(
      client: _currentClientWriter!,
      message: 'Agora é sua vez!\n',
    );
  }

  void _onClientEvent(Uint8List data, ClientModel client) {
    final message = String.fromCharCodes(data);
    if (client.name == null) {
      //first message to server is
      client.name = '[$_clientsLength]$message';
      _onClientJoined(client: client);
    } else if (_clients.length < _minClients) {
      _onWarnMinimunClients();
    } else {
      if (client == _currentClientWriter) {
        // have write Permission
        _onSendMessageToBoard(message: message);
      } else {
        // just a reader, must wait
        _onSendRejection(client: client);
      }
      for (final client in _clients) {
        _onDraw(client: client);
      }
    }
  }

  /* END OF USE CASE */

  /* ||||||||||||||||||||||||||||||| */

  void _onDraw({required ClientModel client}) {
    _messageUser(client: client, message: '\n\n---AVISOS---\n');
    for (final message in _boardMessages) {
      _messageUser(client: client, message: '$message\n');
    }
    _messageUser(client: client, message: '------------\n\n');
  }

  void _onClientJoined({required ClientModel client}) {
    final msg = '${client.name} entrou no servidor';
    _messageAllUsers(message: msg);
  }

  void _onClientDone(ClientModel client) {
    client.connection.close();
    _clients.remove(client);
    final msg = '${client.name} left';
    print(msg);
    _messageAllUsers(message: msg);
  }

  void _onClientError(dynamic error, ClientModel client) {
    print(error);
    client.connection.close();
  }
}
