-- =====================================================================
-- RT CRACKERS | 14_MARKETING/005_Newsletter_subscribers.sql
-- Source: rt_crackers_schema.sql (split by module)
-- =====================================================================

-- ---------------------------------------------------------------------
-- newsletter_subscribers | Purpose: e-mail subscription list (members and guests).
-- Keys : PK(subscriber_id) | CK/AK: email, unsubscribe_token
-- Rel  : N:1 users (optional)
-- BCNF : attributes depend on the subscriber.
-- ---------------------------------------------------------------------
CREATE TABLE newsletter_subscribers (
    subscriber_id      INTEGER       GENERATED ALWAYS AS IDENTITY,
    email              VARCHAR(255)  NOT NULL,
    user_id            BIGINT,
    is_subscribed      BOOLEAN       NOT NULL DEFAULT TRUE,
    subscribed_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    unsubscribed_at    TIMESTAMP,
    unsubscribe_token  VARCHAR(64)   NOT NULL DEFAULT MD5(RANDOM()::TEXT || CLOCK_TIMESTAMP()::TEXT),
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_newsletter_subscribers PRIMARY KEY (subscriber_id),
    CONSTRAINT uq_newsletter_subscribers_email UNIQUE (email),
    CONSTRAINT uq_newsletter_subscribers_token UNIQUE (unsubscribe_token),
    CONSTRAINT fk_newsletter_subscribers_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE SET NULL,
    CONSTRAINT ck_newsletter_subscribers_email CHECK (email = LOWER(email)),
    CONSTRAINT ck_newsletter_subscribers_state CHECK (is_subscribed OR unsubscribed_at IS NOT NULL)
);
