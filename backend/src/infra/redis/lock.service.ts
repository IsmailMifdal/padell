import { Inject, Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { randomBytes } from 'crypto';

// Libération atomique : ne supprime que si on détient encore le verrou
const RELEASE_SCRIPT = `
if redis.call("get", KEYS[1]) == ARGV[1] then
  return redis.call("del", KEYS[1])
else
  return 0
end
`;

/** Verrous distribués Redis (SET NX EX) — anti-concurrence des réservations. */
@Injectable()
export class LockService {
  constructor(@Inject('REDIS_CLIENT') private readonly redis: Redis) {}

  /** Retourne un jeton de verrou, ou null si déjà verrouillé. */
  async acquire(key: string, ttlSeconds: number): Promise<string | null> {
    const token = randomBytes(16).toString('hex');
    const ok = await this.redis.set(key, token, 'EX', ttlSeconds, 'NX');
    return ok === 'OK' ? token : null;
  }

  async release(key: string, token: string): Promise<void> {
    await this.redis.eval(RELEASE_SCRIPT, 1, key, token);
  }

  async disconnect(): Promise<void> {
    await this.redis.quit();
  }
}
