import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(UdpChatApp(initialConfig: ChatConfig.fromArgs(args)));
}

class UdpChatApp extends StatelessWidget {
  const UdpChatApp({super.key, required this.initialConfig});

  final ChatConfig initialConfig;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Задание 3 - UDP чат',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: ChatPage(initialConfig: initialConfig),
    );
  }
}

class ChatConfig {
  const ChatConfig({
    required this.localPort,
    required this.remoteHost,
    required this.remotePort,
    required this.dbPath,
  });

  final int localPort;
  final String remoteHost;
  final int remotePort;
  final String? dbPath;

  factory ChatConfig.defaults() {
    return const ChatConfig(
      localPort: 5001,
      remoteHost: '127.0.0.1',
      remotePort: 5002,
      dbPath: null,
    );
  }

  factory ChatConfig.fromArgs(List<String> args) {
    final values = <String, String>{};
    for (final arg in args) {
      if (!arg.startsWith('--') || !arg.contains('=')) {
        continue;
      }
      final index = arg.indexOf('=');
      values[arg.substring(2, index)] = arg.substring(index + 1);
    }

    return ChatConfig(
      localPort: int.tryParse(values['local-port'] ?? '') ?? 5001,
      remoteHost: values['remote-host'] ?? '127.0.0.1',
      remotePort: int.tryParse(values['remote-port'] ?? '') ?? 5002,
      dbPath: values['db'],
    );
  }
}

class MessageRecord {
  MessageRecord({
    required this.id,
    required this.direction,
    required this.peerHost,
    required this.peerPort,
    required this.text,
    required this.createdAt,
  });

  final int id;
  final String direction;
  final String peerHost;
  final int peerPort;
  final String text;
  final DateTime createdAt;
}

class ChatDatabase {
  Database? _database;

  bool get isOpen => _database != null;

  void open(String dbPath) {
    close();
    final directory = Directory(p.dirname(dbPath));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final database = sqlite3.open(dbPath);
    database.execute('''
CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  direction TEXT NOT NULL,
  peer_host TEXT NOT NULL,
  peer_port INTEGER NOT NULL,
  text TEXT NOT NULL,
  created_at TEXT NOT NULL
);
''');
    _database = database;
  }

  MessageRecord insertMessage({
    required String direction,
    required String peerHost,
    required int peerPort,
    required String text,
  }) {
    final database = _database;
    if (database == null) {
      throw StateError('База данных не открыта');
    }

    final createdAt = DateTime.now();
    database.execute(
      '''
INSERT INTO messages (direction, peer_host, peer_port, text, created_at)
VALUES (?, ?, ?, ?, ?);
''',
      [direction, peerHost, peerPort, text, createdAt.toIso8601String()],
    );

    final id = database.lastInsertRowId;
    return MessageRecord(
      id: id,
      direction: direction,
      peerHost: peerHost,
      peerPort: peerPort,
      text: text,
      createdAt: createdAt,
    );
  }

  List<MessageRecord> loadMessages() {
    final database = _database;
    if (database == null) {
      return [];
    }

    final rows = database.select('''
SELECT id, direction, peer_host, peer_port, text, created_at
FROM messages
ORDER BY id ASC
LIMIT 300;
''');

    return rows.map((row) {
      return MessageRecord(
        id: row['id'] as int,
        direction: row['direction'] as String,
        peerHost: row['peer_host'] as String,
        peerPort: row['peer_port'] as int,
        text: row['text'] as String,
        createdAt:
            DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
      );
    }).toList();
  }

  void close() {
    _database?.close();
    _database = null;
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.initialConfig});

  final ChatConfig initialConfig;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatDatabase _database = ChatDatabase();
  final List<MessageRecord> _messages = [];
  final TextEditingController _messageController = TextEditingController();

  late final TextEditingController _localPortController;
  late final TextEditingController _remoteHostController;
  late final TextEditingController _remotePortController;
  late final TextEditingController _dbPathController;

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  bool _running = false;
  String _status = 'Ожидание запуска';

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _localPortController = TextEditingController(
      text: config.localPort.toString(),
    );
    _remoteHostController = TextEditingController(text: config.remoteHost);
    _remotePortController = TextEditingController(
      text: config.remotePort.toString(),
    );
    _dbPathController = TextEditingController(text: config.dbPath ?? '');
  }

  @override
  void dispose() {
    _stopSocket();
    _database.close();
    _messageController.dispose();
    _localPortController.dispose();
    _remoteHostController.dispose();
    _remotePortController.dispose();
    _dbPathController.dispose();
    super.dispose();
  }

  Future<String> _resolveDbPath() async {
    final enteredPath = _dbPathController.text.trim();
    if (enteredPath.isNotEmpty) {
      return enteredPath;
    }

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'udp_chat_log.db');
    _dbPathController.text = dbPath;
    return dbPath;
  }

  Future<void> _startSocket() async {
    final localPort = int.tryParse(_localPortController.text.trim());
    final remotePort = int.tryParse(_remotePortController.text.trim());
    if (localPort == null || remotePort == null) {
      _showMessage('Порты должны быть числами');
      return;
    }

    try {
      final dbPath = await _resolveDbPath();
      _database.open(dbPath);
      final oldMessages = _database.loadMessages();

      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        localPort,
        reuseAddress: true,
      );
      socket.readEventsEnabled = true;
      _socketSubscription = socket.listen(_handleSocketEvent);

      setState(() {
        _socket = socket;
        _running = true;
        _messages
          ..clear()
          ..addAll(oldMessages);
        _status = 'Запущено. Локальный порт: $localPort';
      });
    } catch (error) {
      _showMessage('Ошибка запуска: $error');
    }
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }

    Datagram? datagram;
    while ((datagram = _socket?.receive()) != null) {
      final current = datagram!;
      final text = utf8.decode(current.data, allowMalformed: true);
      final record = _database.insertMessage(
        direction: 'incoming',
        peerHost: current.address.address,
        peerPort: current.port,
        text: text,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(record);
      });
    }
  }

  Future<void> _sendMessage() async {
    final socket = _socket;
    if (!_running || socket == null) {
      _showMessage('Сначала запустите приложение');
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final remotePort = int.tryParse(_remotePortController.text.trim());
    if (remotePort == null) {
      _showMessage('Порт собеседника должен быть числом');
      return;
    }

    try {
      final address = await _lookupRemoteAddress(
        _remoteHostController.text.trim(),
      );
      final bytes = utf8.encode(text);
      final sent = socket.send(bytes, address, remotePort);
      if (sent <= 0) {
        _showMessage('Сообщение не отправлено');
        return;
      }

      final record = _database.insertMessage(
        direction: 'outgoing',
        peerHost: address.address,
        peerPort: remotePort,
        text: text,
      );

      setState(() {
        _messages.add(record);
        _messageController.clear();
      });
    } catch (error) {
      _showMessage('Ошибка отправки: $error');
    }
  }

  Future<InternetAddress> _lookupRemoteAddress(String host) async {
    final addresses = await InternetAddress.lookup(host);
    return addresses.firstWhere(
      (address) => address.type == InternetAddressType.IPv4,
      orElse: () => addresses.first,
    );
  }

  Future<void> _stopSocket() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
    if (mounted) {
      setState(() {
        _running = false;
        _status = 'Остановлено';
      });
    } else {
      _running = false;
      _status = 'Остановлено';
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Задание 3. UDP-чат и журнал SQLite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionPanel(),
            const SizedBox(height: 12),
            Text(_status, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Expanded(child: _buildMessagesList()),
            const SizedBox(height: 12),
            _buildSendPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionPanel() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        _numberField(
          controller: _localPortController,
          label: 'Локальный порт',
          enabled: !_running,
          width: 150,
        ),
        _textField(
          controller: _remoteHostController,
          label: 'Адрес собеседника',
          enabled: true,
          width: 190,
        ),
        _numberField(
          controller: _remotePortController,
          label: 'Порт собеседника',
          enabled: true,
          width: 160,
        ),
        _textField(
          controller: _dbPathController,
          label: 'Путь к SQLite БД',
          enabled: !_running,
          width: 420,
          hint: 'пусто = udp_chat_log.db в документах приложения',
        ),
        FilledButton.icon(
          onPressed: _running ? _stopSocket : _startSocket,
          icon: Icon(_running ? Icons.stop : Icons.play_arrow),
          label: Text(_running ? 'Остановить' : 'Запустить'),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text('Сообщений пока нет. Запустите два экземпляра приложения.'),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _messages.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final message = _messages[index];
          final outgoing = message.direction == 'outgoing';
          return ListTile(
            leading: Icon(outgoing ? Icons.north_east : Icons.south_west),
            title: Text(message.text),
            subtitle: Text(
              '${outgoing ? 'Исходящее' : 'Входящее'} | '
              '${message.peerHost}:${message.peerPort} | '
              '${_formatTime(message.createdAt)}',
            ),
          );
        },
      ),
    );
  }

  Widget _buildSendPanel() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            enabled: _running,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Сообщение',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _running ? _sendMessage : null,
          icon: const Icon(Icons.send),
          label: const Text('Отправить'),
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required double width,
    String? hint,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}
