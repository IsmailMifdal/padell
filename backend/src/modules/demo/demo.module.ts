import { Module } from '@nestjs/common';
import { DemoService } from './demo.service';

/** Mode démo (DEMO_MODE=true) : comptes invités, remplissage auto et rafraîchissement nocturne. */
@Module({
  providers: [DemoService],
  exports: [DemoService],
})
export class DemoModule {}
