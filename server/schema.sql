-- ============================================================================
-- schema.sql — full table structure for the Pilgrim's Progress backend.
--
-- AUTO-GENERATED from the Alembic migrations (alembic/versions/0001..0010) with:
--     PYTHONPATH=. alembic upgrade head --sql > schema.sql
-- Dialect: PostgreSQL. 12 application tables (+ alembic_version) and 18 indexes.
--
-- You normally DO NOT run this by hand: server/entrypoint.sh runs
-- `alembic upgrade head` on container start, creating exactly these tables in
-- whatever database PP_DATABASE_URL points at (e.g. Neon's "PilgrimsProgressDB").
--
-- Use this file only to create the tables directly — e.g. paste it into Neon's
-- SQL Editor while connected to the PilgrimsProgressDB database. Regenerate with
-- the command above after changing migrations; do not hand-edit.
-- ============================================================================

BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL, 
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> 0001_init

CREATE TABLE players (
    id VARCHAR(36) NOT NULL, 
    device_id VARCHAR(128) NOT NULL, 
    display_name VARCHAR(64) NOT NULL, 
    email VARCHAR(255), 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (id), 
    UNIQUE (device_id), 
    UNIQUE (email)
);

CREATE UNIQUE INDEX ix_players_device_id ON players (device_id);

CREATE TABLE cloud_saves (
    id VARCHAR(36) NOT NULL, 
    player_id VARCHAR(36) NOT NULL, 
    slot_id VARCHAR(32) NOT NULL, 
    version INTEGER NOT NULL, 
    payload JSONB NOT NULL, 
    device_clock TIMESTAMP WITH TIME ZONE, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (id), 
    CONSTRAINT uq_save_slot UNIQUE (player_id, slot_id)
);

CREATE INDEX ix_cloud_saves_player_id ON cloud_saves (player_id);

CREATE TABLE leaderboard_entries (
    id VARCHAR(36) NOT NULL, 
    player_id VARCHAR(36) NOT NULL, 
    board VARCHAR(32) NOT NULL, 
    difficulty VARCHAR(16) NOT NULL, 
    score BIGINT NOT NULL, 
    meta JSONB NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (id)
);

CREATE INDEX ix_leaderboard_entries_player_id ON leaderboard_entries (player_id);

CREATE INDEX ix_board_diff_score ON leaderboard_entries (board, difficulty, score);

CREATE TABLE ghost_trails (
    id VARCHAR(36) NOT NULL, 
    player_id VARCHAR(36) NOT NULL, 
    chapter_id VARCHAR(64) NOT NULL, 
    kind VARCHAR(16) NOT NULL, 
    points JSONB NOT NULL, 
    message TEXT, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (id)
);

CREATE INDEX ix_ghost_trails_player_id ON ghost_trails (player_id);

CREATE INDEX ix_ghost_chapter_created ON ghost_trails (chapter_id, created_at);

CREATE TABLE stat_events (
    id BIGSERIAL NOT NULL, 
    player_id VARCHAR(36), 
    event VARCHAR(64) NOT NULL, 
    chapter_id VARCHAR(64), 
    difficulty VARCHAR(16), 
    props JSONB NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (id)
);

CREATE INDEX ix_stat_events_player_id ON stat_events (player_id);

CREATE INDEX ix_stat_event_created ON stat_events (event, created_at);

CREATE INDEX ix_stat_chapter ON stat_events (chapter_id);

INSERT INTO alembic_version (version_num) VALUES ('0001_init') RETURNING alembic_version.version_num;

-- Running upgrade 0001_init -> 0002_seasons

ALTER TABLE leaderboard_entries ADD COLUMN season VARCHAR(32) DEFAULT 'all' NOT NULL;

CREATE INDEX ix_season_board_diff_score ON leaderboard_entries (season, board, difficulty, score);

UPDATE alembic_version SET version_num='0002_seasons' WHERE alembic_version.version_num = '0001_init';

-- Running upgrade 0002_seasons -> 0003_settlement

CREATE TABLE score_reviews (
    id VARCHAR(36) NOT NULL, 
    entry_id VARCHAR(36) NOT NULL, 
    player_id VARCHAR(36) NOT NULL, 
    season VARCHAR(32) NOT NULL, 
    board VARCHAR(32) NOT NULL, 
    difficulty VARCHAR(16) NOT NULL, 
    score BIGINT NOT NULL, 
    meta JSONB NOT NULL, 
    status VARCHAR(16) NOT NULL, 
    reason VARCHAR(255) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    resolved_at TIMESTAMP WITH TIME ZONE, 
    PRIMARY KEY (id)
);

CREATE INDEX ix_score_reviews_entry_id ON score_reviews (entry_id);

CREATE INDEX ix_score_reviews_player_id ON score_reviews (player_id);

CREATE INDEX ix_review_status ON score_reviews (status, created_at);

CREATE TABLE seasons (
    id VARCHAR(32) NOT NULL, 
    status VARCHAR(16) NOT NULL, 
    settled_at TIMESTAMP WITH TIME ZONE, 
    PRIMARY KEY (id)
);

CREATE TABLE season_rewards (
    id VARCHAR(36) NOT NULL, 
    player_id VARCHAR(36) NOT NULL, 
    season VARCHAR(32) NOT NULL, 
    board VARCHAR(32) NOT NULL, 
    difficulty VARCHAR(16) NOT NULL, 
    rank INTEGER NOT NULL, 
    token VARCHAR(48) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (id), 
    CONSTRAINT uq_reward_slot UNIQUE (season, board, difficulty, rank)
);

CREATE INDEX ix_reward_player ON season_rewards (player_id);

UPDATE alembic_version SET version_num='0003_settlement' WHERE alembic_version.version_num = '0002_seasons';

-- Running upgrade 0003_settlement -> 0004_appeals_seen

ALTER TABLE score_reviews ADD COLUMN appeal_note VARCHAR(280) DEFAULT '' NOT NULL;

ALTER TABLE season_rewards ADD COLUMN seen BOOLEAN DEFAULT false NOT NULL;

UPDATE alembic_version SET version_num='0004_appeals_seen' WHERE alembic_version.version_num = '0003_settlement';

-- Running upgrade 0004_appeals_seen -> 0005_chat

CREATE TABLE chat_messages (
    id VARCHAR(36) NOT NULL, 
    scope VARCHAR(96) NOT NULL, 
    channel VARCHAR(16) NOT NULL, 
    sender_id VARCHAR(36) NOT NULL, 
    sender_name VARCHAR(64) NOT NULL, 
    text TEXT NOT NULL, 
    image_url VARCHAR(255), 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (id)
);

CREATE INDEX ix_chat_messages_sender_id ON chat_messages (sender_id);

CREATE INDEX ix_chat_scope_created ON chat_messages (scope, created_at);

UPDATE alembic_version SET version_num='0005_chat' WHERE alembic_version.version_num = '0004_appeals_seen';

-- Running upgrade 0005_chat -> 0006_dm_unread

CREATE TABLE dm_unread (
    player_id VARCHAR(36) NOT NULL, 
    peer_id VARCHAR(36) NOT NULL, 
    count INTEGER DEFAULT '0' NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (player_id, peer_id)
);

UPDATE alembic_version SET version_num='0006_dm_unread' WHERE alembic_version.version_num = '0005_chat';

-- Running upgrade 0006_dm_unread -> 0007_pins_mentions

CREATE TABLE dm_pins (
    player_id VARCHAR(36) NOT NULL, 
    peer_id VARCHAR(36) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (player_id, peer_id)
);

CREATE TABLE mentions (
    id VARCHAR(36) NOT NULL, 
    player_id VARCHAR(36) NOT NULL, 
    from_id VARCHAR(36) NOT NULL, 
    from_name VARCHAR(64) NOT NULL, 
    channel VARCHAR(16) NOT NULL, 
    scope VARCHAR(96) NOT NULL, 
    text VARCHAR(220) NOT NULL, 
    seen BOOLEAN DEFAULT false NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(), 
    PRIMARY KEY (id)
);

CREATE INDEX ix_mentions_player_id ON mentions (player_id);

CREATE INDEX ix_mention_player_seen ON mentions (player_id, seen);

UPDATE alembic_version SET version_num='0007_pins_mentions' WHERE alembic_version.version_num = '0006_dm_unread';

-- Running upgrade 0007_pins_mentions -> 0008_chat_deleted

ALTER TABLE chat_messages ADD COLUMN deleted BOOLEAN DEFAULT false NOT NULL;

UPDATE alembic_version SET version_num='0008_chat_deleted' WHERE alembic_version.version_num = '0007_pins_mentions';

-- Running upgrade 0008_chat_deleted -> 0009_reply

ALTER TABLE chat_messages ADD COLUMN reply_to VARCHAR(36);

ALTER TABLE chat_messages ADD COLUMN reply_preview VARCHAR(120);

UPDATE alembic_version SET version_num='0009_reply' WHERE alembic_version.version_num = '0008_chat_deleted';

-- Running upgrade 0009_reply -> 0010_avatar

ALTER TABLE players ADD COLUMN avatar_url VARCHAR(255);

UPDATE alembic_version SET version_num='0010_avatar' WHERE alembic_version.version_num = '0009_reply';

COMMIT;

