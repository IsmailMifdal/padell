import { Module } from '@nestjs/common';
import { BookingsModule } from '../bookings/bookings.module';
import { ClubsModule } from '../clubs/clubs.module';
import { PaymentsModule } from '../payments/payments.module';
import { OwnerController } from './owner.controller';
import { OwnerService } from './owner.service';

@Module({
  imports: [BookingsModule, ClubsModule, PaymentsModule],
  controllers: [OwnerController],
  providers: [OwnerService],
})
export class OwnerModule {}
