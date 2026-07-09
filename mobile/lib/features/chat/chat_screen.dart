import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../core/providers.dart';
import '../../core/responsive.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import 'chat_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.matchId});
  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  io.Socket? _socket;
  bool _loading = true;
  bool _connected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final service = ref.read(chatServiceProvider);
    try {
      final history = await service.history(widget.matchId);
      setState(() {
        _messages.addAll(history);
        _loading = false;
      });
      _jumpToEnd();
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
      return;
    }

    final token = await ref.read(tokenStorageProvider).accessToken;
    if (token == null) return;
    final socket = service.connect(token);
    _socket = socket;
    socket
      ..onConnect((_) {
        socket.emit('join', {'matchId': widget.matchId});
        if (mounted) setState(() => _connected = true);
      })
      ..onDisconnect((_) {
        if (mounted) setState(() => _connected = false);
      })
      ..on('message', (data) {
        if (!mounted || data is! Map) return;
        final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));
        // Le broadcast inclut nos propres messages : déduplication par id
        if (_messages.any((m) => m.id == msg.id)) return;
        setState(() => _messages.add(msg));
        _jumpToEnd();
      })
      ..connect();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _socket == null) return;
    _socket!.emit('message', {'matchId': widget.matchId, 'body': text});
    _input.clear();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _socket?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authControllerProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat du match'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  height: 9,
                  width: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connected ? AppColors.primary : AppColors.slate,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _connected ? 'En ligne' : 'Hors ligne',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.slate),
                ),
              ],
            ),
          ),
        ],
      ),
      body: PageContainer(
        maxWidth: 760,
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const CenteredLoader()
                  : _error != null
                      ? ErrorRetry(
                          message: _error!,
                          onRetry: () {
                            setState(() {
                              _error = null;
                              _loading = true;
                              _messages.clear();
                            });
                            _bootstrap();
                          },
                        )
                      : _messages.isEmpty
                          ? const EmptyState(
                              icon: Icons.chat_bubble_outline,
                              title: 'Pas encore de messages',
                              subtitle:
                                  'Écrivez le premier message à vos partenaires !',
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              itemCount: _messages.length,
                              itemBuilder: (context, i) => _Bubble(
                                message: _messages[i],
                                isMine: _messages[i].senderId == myId,
                              ),
                            ),
            ),
            // Zone de saisie
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                10 + MediaQuery.of(context).viewPadding.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: softShadow(0.06),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Votre message…',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _send,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child:
                            Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          gradient: isMine ? AppColors.heroGradient : null,
          color: isMine ? null : scheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: softShadow(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                color: isMine ? Colors.white : scheme.onSurface,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(message.sentAt),
              style: TextStyle(
                fontSize: 10,
                color: isMine
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
