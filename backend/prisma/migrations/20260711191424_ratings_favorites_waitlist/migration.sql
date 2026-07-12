-- CreateTable
CREATE TABLE "ratings" (
    "id" TEXT NOT NULL,
    "match_id" TEXT NOT NULL,
    "rater_id" TEXT NOT NULL,
    "rated_id" TEXT NOT NULL,
    "punctuality" INTEGER NOT NULL,
    "fairplay" INTEGER NOT NULL,
    "level_accuracy" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ratings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "favorite_clubs" (
    "user_id" TEXT NOT NULL,
    "club_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "favorite_clubs_pkey" PRIMARY KEY ("user_id","club_id")
);

-- CreateTable
CREATE TABLE "waitlist_entries" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "club_id" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "waitlist_entries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ratings_match_id_rater_id_rated_id_key" ON "ratings"("match_id", "rater_id", "rated_id");

-- CreateIndex
CREATE INDEX "waitlist_entries_club_id_date_idx" ON "waitlist_entries"("club_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "waitlist_entries_user_id_club_id_date_key" ON "waitlist_entries"("user_id", "club_id", "date");

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_rater_id_fkey" FOREIGN KEY ("rater_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_rated_id_fkey" FOREIGN KEY ("rated_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "favorite_clubs" ADD CONSTRAINT "favorite_clubs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "favorite_clubs" ADD CONSTRAINT "favorite_clubs_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "clubs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "waitlist_entries" ADD CONSTRAINT "waitlist_entries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "waitlist_entries" ADD CONSTRAINT "waitlist_entries_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "clubs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

