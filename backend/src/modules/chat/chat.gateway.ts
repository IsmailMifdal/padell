import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtPayload } from '../auth/jwt.strategy';
import { ChatService } from './chat.service';

interface AuthedSocket extends Socket {
  data: { userId: string };
}

/**
 * Chat de match temps réel. Auth JWT au handshake :
 * io('/chat', { auth: { token: '<accessToken>' } })
 * Événements : join { matchId } · message { matchId, body } → broadcast "message".
 */
@WebSocketGateway({ namespace: '/chat', cors: { origin: true } })
export class ChatGateway implements OnGatewayConnection {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(ChatGateway.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly chat: ChatService,
  ) {}

  async handleConnection(client: AuthedSocket) {
    try {
      const token =
        client.handshake.auth?.token ??
        client.handshake.headers.authorization?.replace(/^Bearer /, '');
      const payload = await this.jwt.verifyAsync<JwtPayload>(token);
      client.data.userId = payload.sub;
    } catch {
      client.disconnect(true);
    }
  }

  @SubscribeMessage('join')
  async join(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { matchId: string },
  ) {
    if (!body?.matchId) throw new WsException('matchId requis');
    try {
      await this.chat.assertParticipant(client.data.userId, body.matchId);
    } catch (e) {
      throw new WsException(e instanceof Error ? e.message : 'Accès refusé');
    }
    await client.join(`match:${body.matchId}`);
    return { joined: body.matchId };
  }

  @SubscribeMessage('message')
  async message(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { matchId: string; body: string },
  ) {
    const text = body?.body?.trim();
    if (!body?.matchId || !text || text.length > 1000) {
      throw new WsException('Message invalide');
    }
    let saved;
    try {
      saved = await this.chat.saveMessage(client.data.userId, body.matchId, text);
    } catch (e) {
      throw new WsException(e instanceof Error ? e.message : 'Accès refusé');
    }
    this.server.to(`match:${body.matchId}`).emit('message', saved);
    return { sent: saved.id };
  }
}
