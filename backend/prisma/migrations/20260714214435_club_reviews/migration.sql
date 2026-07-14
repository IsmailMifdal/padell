-- CreateTable
CREATE TABLE "club_reviews" (
    "id" TEXT NOT NULL,
    "club_id" TEXT NOT NULL,
    "booking_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "rating" INTEGER NOT NULL,
    "comment" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "club_reviews_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "club_reviews_club_id_created_at_idx" ON "club_reviews"("club_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "club_reviews_booking_id_user_id_key" ON "club_reviews"("booking_id", "user_id");

-- AddForeignKey
ALTER TABLE "club_reviews" ADD CONSTRAINT "club_reviews_club_id_fkey" FOREIGN KEY ("club_id") REFERENCES "clubs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "club_reviews" ADD CONSTRAINT "club_reviews_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "club_reviews" ADD CONSTRAINT "club_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

