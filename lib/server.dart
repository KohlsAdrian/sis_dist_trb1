import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:trabalho_01/models/client_model.dart';

import 'data/constants.dart';

class ExclusaoMutuaServer {
  ExclusaoMutuaServer._();
  static final ExclusaoMutuaServer _instance = ExclusaoMutuaServer._();
  static ExclusaoMutuaServer get instance => _instance;

  /// exclusion flag
  ClientModel? _currentClientWriter;

  final _clients = ListQueue<ClientModel>();

  /// clients FIFO
  int get _clientsLength => _clients.length;

  final _boardMessages = <String>[];
  Timer? _debounce;

  void run() async {
    final server = await ServerSocket.bind(host, port);
    server.listen(_onClientConnect);
  }

  void _startClientTimer() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(maxClientWaitTimeDuration, _onNextQueue);
  }

  void _onClientConnect(Socket connection) {
    final client = ClientModel(connection: connection);

    /// first client always the main WRITER
    if (_clients.isEmpty) {
      _currentClientWriter = client;
    }

    if (_clients.length >= minimumClientsBoard) {
      /// start debounce only on minimum client connections
      _startClientTimer();
    } else {
      /// cancel debounce on disconnects if less than minimum clients
      _debounce?.cancel();
    }

    _clients.add(client);

    /// new connection goes to end of the queue

    /// listen to client events
    client.connection.listen(
      (data) => _onClientEvent(data, client),
      onDone: () => _onClientDone(client),
      onError: (error) => _onClientError(error, client),
    );
  }

  /// |||||||||||||||||||||||||||||||

  /// START OF MESSAGING
  void _messageAllUsers({required String message}) {
    for (final client in _clients) {
      _messageUser(client: client, message: message);
    }
  }

  void _messageUser({required ClientModel client, required String message}) {
    client.connection.writeln(message);
  }

  void _onSendMessageToBoard({required String message}) {
    /// test if first in the QUEUE is the WRITER
    assert(_clients.first == _currentClientWriter);
    _boardMessages.add(message);
    _onNextQueue();
  }

  void _onSendRejection({required ClientModel client}) {
    /// PERFORMANCE ISSUE (convert structure to list to get INDEX)
    final queueIndex = _clients.toList().indexOf(client);
    _messageUser(
      client: client,
      message: 'Não é sua vez ainda! Aguarde! '
          '$queueIndex/$_clientsLength',
    );
  }

  void _onWarnMinimunClients() {
    final message = 'Aguardando clientes \n'
        '[$_clientsLength/$minimumClientsBoard]';
    for (final client in _clients) {
      client.connection.write(message);
    }
  }

  void _onDrawBoard() {
    String boardMessages = '';
    for (final msg in _boardMessages) {
      boardMessages += '$msg\n';
    }
    _messageAllUsers(
      message: '---AVISOS---\n'
          '$boardMessages'
          '------------\n',
    );
  }

  /// END OF MESSAGING

  /// |||||||||||||||||||||||||||||||

  /// START OF USE CASE

  void _onNextQueue() {
    if (_clients.isNotEmpty) {
      ClientModel client = _clients.removeFirst();

      /// remove first in the QUEUE
      _clients.add(client);

      /// add to the end of the QUEUE
      _currentClientWriter = _clients.first;

      /// writer is the first in the QUEUE

      /// message old first QUEUER
      _messageUser(
        client: client,
        message: 'Você foi colocado no final da fila!',
      );

      /// message new first QUEUER
      _messageUser(
        client: _currentClientWriter!,
        message: 'Agora é sua vez!\n'
            '5 segundos!!! Tic tac!',
      );
    }

    /// reset timer for current writer
    _startClientTimer();
  }

  void _onClientEvent(Uint8List data, ClientModel client) {
    print('\x1B[2J\x1B[0;0H');

    /// clear entire screen, move cursor to 0;0
    final message = String.fromCharCodes(data);
    if (client.name == null) {
      //first message to server is
      client.name = message;
      _onClientJoined(client: client);
    } else if (_clients.length < minimumClientsBoard) {
      _onWarnMinimunClients();
    } else {
      if (client == _currentClientWriter) {
        /// have write Permission
        _onSendMessageToBoard(message: message);
      } else {
        /// just a reader, must wait
        _onSendRejection(client: client);
      }
      _onDrawBoard();
    }
  }

  /// END OF USE CASE

  /// |||||||||||||||||||||||||||||||
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
    _clients.remove(client);
  }
}
