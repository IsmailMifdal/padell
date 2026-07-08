-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('PENDING_PAYMENT', 'CONFIRMED', 'CANCELLED', 'COMPLETED', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "BookingSource" AS ENUM ('APP', 'MANUAL', 'BLOCKED');

-- CreateEnum
CREATE TYPE "PaymentMode" AS ENUM ('ONLINE', 'ON_SITE');

-- CreateTable
CREATE TABLE "bookings" (
    "id" TEXT NOT NULL,
    "court_id" TEXT NOT NULL,
    "booked_by" TEXT,
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3) NOT NULL,
    "price_mad" DECIMAL(8,2) NOT NULL,
    "status" "BookingStatus" NOT NULL DEFAULT 'PENDING_PAYMENT',
    "source" "BookingSource" NOT NULL DEFAULT 'APP',
    "payment_mode" "PaymentMode",
    "qr_code" TEXT,
    "cancellation_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "bookings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "bookings_qr_code_key" ON "bookings"("qr_code");

-- CreateIndex
CREATE INDEX "bookings_court_id_starts_at_idx" ON "bookings"("court_id", "starts_at");

-- CreateIndex
CREATE INDEX "bookings_booked_by_starts_at_idx" ON "bookings"("booked_by", "starts_at");

-- CreateIndex
CREATE INDEX "bookings_status_created_at_idx" ON "bookings"("status", "created_at");

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_court_id_fkey" FOREIGN KEY ("court_id") REFERENCES "courts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_booked_by_fkey" FOREIGN KEY ("booked_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Filet de securite anti-double-reservation (concurrence)
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_no_overlap"
  EXCLUDE USING gist ("court_id" WITH =, tsrange("starts_at", "ends_at") WITH &&)
  WHERE ("status" IN ('PENDING_PAYMENT', 'CONFIRMED'));
