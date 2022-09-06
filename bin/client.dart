import 'package:trabalho_01/core/client/client.dart';

void main(List<String> arguments) {
  final name = arguments.isEmpty ? 'Unix USER' : arguments[0];
  ExclusaoMutuaClient.instance.run(name: name);
}
