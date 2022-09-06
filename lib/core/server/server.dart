import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:trabalho_01/core/server/server_messaging.dart';
import 'package:trabalho_01/data/models/client_model.dart';

import '../../data/constants.dart';

class ExclusaoMutuaServer {
  ExclusaoMutuaServer._();
  static final ExclusaoMutuaServer _instance = ExclusaoMutuaServer._();
  static ExclusaoMutuaServer get instance => _instance;

  /// exclusion flag
  ClientModel? _currentClientWriter;

  final _clients = ListQueue<ClientModel>();
  late final _serverMessaging = ServerMessaging(_clients);

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

  void _onNextQueue() {
    if (_clients.isNotEmpty) {
      ClientModel client = _clients.removeFirst();

      /// remove first in the QUEUE
      _clients.add(client);

      /// add to the end of the QUEUE
      _currentClientWriter = _clients.first;

      /// writer is the first in the QUEUE

      /// message old first QUEUER
      _serverMessaging.messageUser(
        client: client,
        message: 'Você foi colocado no final da fila!',
      );

      /// message new first QUEUER
      _serverMessaging.messageUser(
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
      _serverMessaging.warnMinimunClients();
    } else {
      if (client == _currentClientWriter) {
        /// have write Permission
        _serverMessaging.sendMessageToBoard(
          message: message,
          clientWriter: _currentClientWriter,
          boardMessages: _boardMessages,
          onNext: _onNextQueue,
        );
      } else {
        /// just a reader, must wait
        _serverMessaging.sendRejectionMessage(client: client);
      }
      _serverMessaging.drawBoard(boardMessages: _boardMessages);
    }
  }

  /// |||||||||||||||||||||||||||||||
  void _onClientJoined({required ClientModel client}) {
    final msg = '${client.name} entrou no servidor';
    _serverMessaging.messageAllUsers(message: msg);
  }

  void _onClientDone(ClientModel client) {
    client.connection.close();
    _clients.remove(client);
    final msg = '${client.name} left';
    print(msg);
    _serverMessaging.messageAllUsers(message: msg);
  }

  void _onClientError(dynamic error, ClientModel client) {
    print(error);
    client.connection.close();
    _clients.remove(client);
  }
}
