import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/config.dart';
import '../../core/providers.dart';

final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService(ref.watch(apiClientProvider).dio),
);

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.body,
    required this.sentAt,
    required this.senderId,
    required this.senderName,
  });

  final String id;
  final String body;
  final DateTime sentAt;
  final String senderId;
  final String senderName;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final sender = (j['sender'] ?? {}) as Map<String, dynamic>;
    final profile = (sender['profile'] ?? {}) as Map<String, dynamic>;
    return ChatMessage(
      id: j['id'] as String,
      body: (j['body'] ?? '') as String,
      sentAt: DateTime.parse(j['sentAt'] as String),
      senderId: (sender['id'] ?? '') as String,
      senderName:
          '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim(),
    );
  }
}

class ChatService {
  ChatService(this._dio);
  final Dio _dio;

  /// Historique des messages (REST, participants uniquement).
  Future<List<ChatMessage>> history(String matchId) async {
    final res = await _dio.get<List<dynamic>>('/matches/$matchId/messages');
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  /// Ouvre la connexion temps réel vers le namespace /chat du backend.
  io.Socket connect(String accessToken) {
    // http://host:port/v1 → http://host:port (le namespace est /chat)
    final base = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/v1/?$'), '');
    return io.io(
      '$base/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .disableAutoConnect()
          .build(),
    );
  }
}
