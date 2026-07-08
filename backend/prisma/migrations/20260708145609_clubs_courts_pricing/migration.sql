-- Extension PostGIS pour la recherche geographique
CREATE EXTENSION IF NOT EXISTS postgis;

-- CreateEnum
CREATE TYPE "ClubStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "CourtType" AS ENUM ('INDOOR', 'OUTDOOR', 'PANORAMIC');

-- CreateTable
CREATE TABLE "clubs" (
    "id" TEXT NOT NULL,
    "owner_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "address" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "phone" TEXT,
    "latitude" DECIMAL(9,6) NOT NULL,
    "longitude" DECIMAL(9,6) NOT NULL,
    "amenities" JSONB NOT NULL DEFAULT '[]',
    "cancellation_policy" JSONB,
    "commission_rate" DECIMAL(4,2) NOT NULL DEFAULT 10.00,
    "payment_on_site_allowed" BOOLEAN NOT NULL DEFAULT true,
    "status" "ClubStatus" NOT NULL DEFAULT 'PENDING',
    "rating_avg" DECIMAL(2,1),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "clubs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "courts" (
    "id" TEXT NOT NULL,
    "club_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "CourtType" NOT NULL DEFAULT 'OUTDOOR',
    "photos" JSONB NOT NULL DEFAULT '[]',
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "courts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "opening_hours" (
    "id" TEXT NOT NULL,
    "club_id" TEXT NOT NULL,
    "day_of_week" INTEGER NOT NULL,
    "open_min" INTEGER NOT NULL,
    "close_min" INTEGER NOT NULL,

    CONSTRAINT "opening_hours_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pricing_rules" (
    "id" TEXT NOT NULL,
    "court_id" TEXT NOT NULL,
    "day_of_week" INTEGER NOT NULL,
    "start_min" INTEGER NOT NULL,
    "end_min" INTEGER NOT NULL,
    "duration_min" INTEGER NOT NULL,
    "price_mad" DECIMAL(8,2) NOT NULL,

    CONSTRAINT "pricing_rules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "availabilities" (
    "id" TEXT NOT NULL,
    "player_id" TEXT NOT NULL,
    "day_of_week" INTEGER NOT NULL,
    "start_min" INTEGER NOT NULL,
    "end_min" INTEGER NOT NULL,

    CONSTRAINT "availabilities_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "clubs_owner_id_idx" ON "clubs"("owner_id");

-- CreateIndex
CREATE INDEX "clubs_status_city_idx" ON "clubs"("status", "city");

-- CreateIndex
CREATE INDEX "courts_club_id_idx" ON "courts"("club_id");

-- CreateIndex
CREATE UNIQUE INDEX "opening_hours_club_id_day_of_week_key" ON "opening_hours"("club_id", "day_of_week");

-- CreateIndex
CREATE INDEX "pricing_rules_court_id_day_of_week_idx" ON "pricing_rules"("court_id", "day_of_week");

-- CreateIndex
CREATE INDEX "availabilities_player_id_idx" ON "availabilities"("player_id");

-- AddForeignKey
ALTER TABLE "clubs" ADD CONSTRAINT "clubs_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "courts" ADD CONSTRAINT "courts_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "clubs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opening_hours" ADD CONSTRAINT "opening_hours_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "clubs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pricing_rules" ADD CONSTRAINT "pricing_rules_court_id_fkey" FOREIGN KEY ("court_id") REFERENCES "courts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "availabilities" ADD CONSTRAINT "availabilities_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "player_profiles"("user_id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Index GIST fonctionnel pour la recherche de clubs par rayon
CREATE INDEX "clubs_location_gist" ON "clubs" USING gist ((ST_SetSRID(ST_MakePoint(longitude::float8, latitude::float8), 4326)::geography));
