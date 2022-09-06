import 'package:trabalho_01/core/server/server.dart';
import 'package:trabalho_01/data/constants.dart';

void main(List<String> arguments) {
  try {
    final minimumClients = arguments.isEmpty ? "5" : arguments[0];
    minimumClientsBoard = int.parse(minimumClients);
  } catch (e) {
    print(e);
  }
  ExclusaoMutuaServer.instance.run();
}
