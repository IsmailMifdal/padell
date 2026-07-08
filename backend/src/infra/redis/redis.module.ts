import { Global, Module, OnApplicationShutdown } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import { LockService } from './lock.service';

export const REDIS = 'REDIS_CLIENT';

@Global()
@Module({
  providers: [
    {
      provide: REDIS,
      inject: [ConfigService],
      useFactory: (config: ConfigService) =>
        new Redis(config.get<string>('REDIS_URL') ?? 'redis://localhost:6379', {
          maxRetriesPerRequest: 3,
        }),
    },
    LockService,
  ],
  exports: [REDIS, LockService],
})
export class RedisModule implements OnApplicationShutdown {
  constructor(private readonly lockService: LockService) {}

  async onApplicationShutdown() {
    await this.lockService.disconnect();
  }
}
