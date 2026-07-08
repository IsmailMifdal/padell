import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { ReportsController } from './reports.controller';

@Module({
  controllers: [AdminController, ReportsController],
  providers: [AdminService],
})
export class AdminModule {}
