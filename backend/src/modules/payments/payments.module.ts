import { Module } from '@nestjs/common';
import { ClubsModule } from '../clubs/clubs.module';
import { CmiService } from './cmi.service';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

@Module({
  imports: [ClubsModule],
  controllers: [PaymentsController],
  providers: [PaymentsService, CmiService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
