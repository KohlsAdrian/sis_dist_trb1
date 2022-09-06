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

  void _resetTimerWriter() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(maxClientWaitTimeDuration, _onNextQueue);
  }

  void _onClientConnect(Socket connection) {
    final client = ClientModel(connection: connection);

    /// listen to client events
    client.connection.listen(
      (data) => _onClientEvent(data, client),
      onDone: () => _onClientDone(client),
      onError: (error) => _onClientError(error, client),
    );

    /// new connection goes to end of the queue
    _clients.add(client);

    final hasMinClients = _clients.length >= minimumClientsBoard;
    final isTimerOn = (_debounce?.isActive ?? false);
    if (hasMinClients && !isTimerOn) {
      /// start debounce only on minimum client connections
      _onNextQueue();
      _resetTimerWriter();
    } else if (!hasMinClients) {
      /// cancel debounce on disconnects if less than minimum clients
      _debounce?.cancel();
    }
  }

  /// |||||||||||||||||||||||||||||||

  void _onNextQueue() {
    if (_currentClientWriter == null && _clients.isNotEmpty) {
      /// writer is the first in the QUEUE
      _currentClientWriter = _clients.first;
    } else if (_clients.isNotEmpty) {
      /// move first in the QUEUE to the end
      ClientModel lastClient = _clients.removeFirst();
      _clients.add(lastClient);

      /// set new WRITER QUEUEr
      _currentClientWriter = _clients.first;

      /// message new queuer and old first queuer
      _serverMessaging
        ..messageUser(
          client: lastClient, // message old first QUEUER
          message: 'Você foi colocado no final da fila!',
        )
        ..messageUser(
          client: _currentClientWriter!, // message new first QUEUER
          message: 'Agora é sua vez!\n'
              '${maxClientWaitTimeDuration.inSeconds} segundos!!!'
              '\nTic tac!!!!',
        );

      /// reset timer for current writer
      _resetTimerWriter();
    }
  }

  void _onClientEvent(Uint8List data, ClientModel client) {
    print('\x1B[2J\x1B[0;0H');

    /// clear entire screen, move cursor to 0;0
    final message = String.fromCharCodes(data);
    print(message);
    if (client.name == null) {
      //first message to server is
      client.name = message;
      _onClientJoined(client: client);
    } else if (_clients.length < minimumClientsBoard) {
      _serverMessaging.warnMinimunClients();
    } else {
      final isWritter = client == _currentClientWriter;
      if (isWritter) {
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
