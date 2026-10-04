-- =====================================================================
-- RT CRACKERS | 08_WISHLIST/001_Wishlists.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- wishlists | Purpose: named wish lists per user.
-- Keys : PK(wishlist_id) | CK/AK: (user_id, wishlist_name)
-- Rel  : N:1 users; 1:N wishlist_items
-- BCNF : attributes depend on the wishlist.
-- ---------------------------------------------------------------------
CREATE TABLE wishlists (
    wishlist_id    BIGINT        GENERATED ALWAYS AS IDENTITY,
    user_id        BIGINT        NOT NULL,
    wishlist_name  VARCHAR(80)   NOT NULL DEFAULT 'My Wishlist',
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_wishlists PRIMARY KEY (wishlist_id),
    CONSTRAINT uq_wishlists_user_name UNIQUE (user_id, wishlist_name),
    CONSTRAINT fk_wishlists_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
