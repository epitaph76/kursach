import 'package:flutter_test/flutter_test.dart';
import 'package:zadanie_3_udp_chat/main.dart';

void main() {
  testWidgets('udp chat app shows launch controls', (tester) async {
    await tester.pumpWidget(UdpChatApp(initialConfig: ChatConfig.defaults()));

    expect(find.text('Запустить'), findsOneWidget);
    expect(find.text('Локальный порт'), findsOneWidget);
  });

  test('command line arguments are parsed', () {
    final config = ChatConfig.fromArgs([
      '--db=C:/temp/chat.db',
      '--local-port=6001',
      '--remote-host=127.0.0.1',
      '--remote-port=6002',
    ]);

    expect(config.dbPath, 'C:/temp/chat.db');
    expect(config.localPort, 6001);
    expect(config.remotePort, 6002);
  });
}
