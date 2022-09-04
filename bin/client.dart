import 'package:trabalho_01/client.dart';

void main(List<String> arguments) =>
    ExclusaoMutuaClient.instance.run(name: arguments[0]);
