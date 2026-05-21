import 'dart:convert';
import 'dart:io';

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

  testWidgets('incoming UDP message appears without restarting chat', (
    tester,
  ) async {
    final localPort = await _freeUdpPort();
    final tempDirectory = Directory.systemTemp.createTempSync('udp_chat_test_');
    addTearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    await tester.pumpWidget(
      UdpChatApp(
        initialConfig: ChatConfig(
          localPort: localPort,
          remoteHost: '127.0.0.1',
          remotePort: localPort + 1,
          dbPath: '${tempDirectory.path}/chat.db',
        ),
      ),
    );

    await tester.tap(find.text('Запустить'));
    await tester.pump(const Duration(milliseconds: 300));

    final sender = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(sender.close);
    sender.send(
      utf8.encode('сообщение сразу'),
      InternetAddress.loopbackIPv4,
      localPort,
    );

    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('сообщение сразу'), findsOneWidget);

    await tester.tap(find.text('Остановить'));
    await tester.pump(const Duration(milliseconds: 300));
  });
}

Future<int> _freeUdpPort() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  socket.close();
  return port;
}
