import { Module } from '@nestjs/common';
import { ClubsModule } from '../clubs/clubs.module';
import { PaymentsModule } from '../payments/payments.module';
import { OwnerController } from './owner.controller';
import { OwnerService } from './owner.service';

@Module({
  imports: [ClubsModule, PaymentsModule],
  controllers: [OwnerController],
  providers: [OwnerService],
})
export class OwnerModule {}
