import { Module } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module';
import { AvailabilityService } from './availability.service';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { WaitlistService } from './waitlist.service';

@Module({
  imports: [PaymentsModule],
  controllers: [BookingsController],
  providers: [BookingsService, AvailabilityService, WaitlistService],
  exports: [BookingsService, AvailabilityService, WaitlistService],
})
export class BookingsModule {}
