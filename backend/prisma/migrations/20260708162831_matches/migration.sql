-- CreateEnum
CREATE TYPE "MatchStatus" AS ENUM ('OPEN', 'FULL', 'CONFIRMED', 'PLAYED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "MatchVisibility" AS ENUM ('PUBLIC', 'PRIVATE');

-- CreateEnum
CREATE TYPE "MatchPlayerStatus" AS ENUM ('REQUESTED', 'ACCEPTED', 'DECLINED', 'WITHDRAWN');

-- AlterTable
ALTER TABLE "payments" ADD COLUMN     "match_id" TEXT;

-- CreateTable
CREATE TABLE "matches" (
    "id" TEXT NOT NULL,
    "creator_id" TEXT NOT NULL,
    "booking_id" TEXT,
    "club_id" TEXT NOT NULL,
    "starts_at" TIMESTAMP(3) NOT NULL,
    "duration_min" INTEGER NOT NULL,
    "level_min" DECIMAL(2,1) NOT NULL,
    "level_max" DECIMAL(2,1) NOT NULL,
    "visibility" "MatchVisibility" NOT NULL DEFAULT 'PUBLIC',
    "price_per_player_mad" DECIMAL(8,2) NOT NULL,
    "status" "MatchStatus" NOT NULL DEFAULT 'OPEN',
    "score" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "matches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "match_players" (
    "id" TEXT NOT NULL,
    "match_id" TEXT NOT NULL,
    "player_id" TEXT NOT NULL,
    "team" INTEGER,
    "status" "MatchPlayerStatus" NOT NULL DEFAULT 'REQUESTED',
    "payment_id" TEXT,
    "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "match_players_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "matches_booking_id_key" ON "matches"("booking_id");

-- CreateIndex
CREATE INDEX "matches_status_starts_at_idx" ON "matches"("status", "starts_at");

-- CreateIndex
CREATE INDEX "matches_club_id_starts_at_idx" ON "matches"("club_id", "starts_at");

-- CreateIndex
CREATE UNIQUE INDEX "match_players_payment_id_key" ON "match_players"("payment_id");

-- CreateIndex
CREATE UNIQUE INDEX "match_players_match_id_player_id_key" ON "match_players"("match_id", "player_id");

-- CreateIndex
CREATE INDEX "payments_match_id_idx" ON "payments"("match_id");

-- AddForeignKey
ALTER TABLE "matches" ADD CONSTRAINT "matches_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "matches" ADD CONSTRAINT "matches_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "matches" ADD CONSTRAINT "matches_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "clubs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_players" ADD CONSTRAINT "match_players_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_players" ADD CONSTRAINT "match_players_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_players" ADD CONSTRAINT "match_players_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "payments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

