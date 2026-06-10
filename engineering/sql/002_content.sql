-- ============================================================
-- MindFrame Database Schema — Migration 002: Content Tables
-- ============================================================

BEGIN;

-- ============================
-- Content Templates (10 script templates)
-- ============================
CREATE TABLE content_templates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name            TEXT NOT NULL UNIQUE,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,

    hook_format         TEXT NOT NULL,
    point_1_framework   TEXT NOT NULL,
    point_2_framework   TEXT NOT NULL,
    point_3_framework   TEXT NOT NULL,
    cta_framework       TEXT NOT NULL,

    category        TEXT NOT NULL,
    primary_trigger TEXT,

    avg_performance     DECIMAL(3,1) DEFAULT 0.0,
    times_used          INT DEFAULT 0,
    is_active           BOOLEAN DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_content_templates_updated_at
    BEFORE UPDATE ON content_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================
-- Viral Hooks Database
-- ============================
CREATE TABLE viral_hooks (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    hook_text           TEXT NOT NULL,
    category            TEXT NOT NULL,
    trigger_type        TEXT NOT NULL,

    estimated_performance   DECIMAL(3,1) NOT NULL CHECK (estimated_performance >= 0 AND estimated_performance <= 10),
    actual_performance      DECIMAL(3,1),
    performance_delta       DECIMAL(4,2) GENERATED ALWAYS AS (
        CASE WHEN actual_performance IS NOT NULL 
             THEN actual_performance - estimated_performance 
             ELSE NULL 
        END
    ) STORED,

    times_used          INT DEFAULT 0,
    last_used_at        TIMESTAMPTZ,

    variant_group       TEXT,
    winning_variant_id  UUID REFERENCES viral_hooks(id) ON DELETE SET NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE viral_hooks ADD CONSTRAINT uq_viral_hooks_text UNIQUE (hook_text);

CREATE TRIGGER trg_viral_hooks_updated_at
    BEFORE UPDATE ON viral_hooks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_viral_hooks_category ON viral_hooks(category);
CREATE INDEX idx_viral_hooks_trigger_type ON viral_hooks(trigger_type);
CREATE INDEX idx_viral_hooks_performance ON viral_hooks(estimated_performance DESC);
CREATE INDEX idx_viral_hooks_actual_performance ON viral_hooks(actual_performance DESC NULLS LAST);

-- ============================
-- Content Scripts
-- ============================
CREATE TABLE content_scripts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    title           TEXT NOT NULL,
    hook_text       TEXT NOT NULL,
    body_text       TEXT NOT NULL,
    cta_text        TEXT,

    ai_prompt       TEXT,
    ai_temperature  DECIMAL(3,2) DEFAULT 0.7,
    ai_model        TEXT DEFAULT 'gpt-4',
    tokens_used     INT,

    version         INT NOT NULL DEFAULT 1,
    previous_version_id UUID REFERENCES content_scripts(id) ON DELETE SET NULL,

    tags            TEXT[] DEFAULT '{}',
    category        TEXT,
    estimated_performance DECIMAL(3,1),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_content_scripts_updated_at
    BEFORE UPDATE ON content_scripts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_content_scripts_category ON content_scripts(category);
CREATE INDEX idx_content_scripts_tags ON content_scripts USING GIN(tags);

-- ============================
-- Content Videos
-- ============================
CREATE TABLE content_videos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    title           TEXT NOT NULL,
    slug            TEXT UNIQUE NOT NULL,
    hook_id         UUID REFERENCES viral_hooks(id) ON DELETE SET NULL,
    template_id     UUID REFERENCES content_templates(id) ON DELETE SET NULL,

    script_id       UUID REFERENCES content_scripts(id) ON DELETE SET NULL,
    script_text     TEXT NOT NULL,
    word_count      INT,

    platforms       TEXT[] NOT NULL DEFAULT '{}',
    published_at    TIMESTAMPTZ,
    scheduled_for   TIMESTAMPTZ,

    video_url       TEXT,
    thumbnail_url   TEXT,
    s3_storage_path TEXT,
    duration_seconds INT,

    ai_model        TEXT DEFAULT 'elevenlabs',
    ai_voice_id     TEXT,

    status          TEXT NOT NULL DEFAULT 'draft' 
                    CHECK (status IN ('draft', 'rendering', 'scheduled', 'published', 'failed', 'archived')),

    total_views         BIGINT DEFAULT 0,
    total_likes         BIGINT DEFAULT 0,
    total_shares        BIGINT DEFAULT 0,
    total_comments      BIGINT DEFAULT 0,
    total_saves         BIGINT DEFAULT 0,
    avg_watch_seconds   DECIMAL(5,2),

    cta_type        TEXT,
    cta_url         TEXT,
    cta_clicks      BIGINT DEFAULT 0,

    seo_tags        TEXT[],
    seo_description TEXT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_content_videos_updated_at
    BEFORE UPDATE ON content_videos
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_content_videos_status ON content_videos(status);
CREATE INDEX idx_content_videos_published_at ON content_videos(published_at);
CREATE INDEX idx_content_videos_hook_id ON content_videos(hook_id);
CREATE INDEX idx_content_videos_platforms ON content_videos USING GIN(platforms);

-- Partial index for recent published videos
CREATE INDEX idx_videos_recent ON content_videos(published_at DESC) 
    WHERE status = 'published' AND published_at > NOW() - INTERVAL '30 days';

-- ============================
-- Content Publishing Queue
-- ============================
CREATE TABLE content_publishing_queue (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id        UUID NOT NULL REFERENCES content_videos(id) ON DELETE CASCADE,

    platform        TEXT NOT NULL CHECK (platform IN ('tiktok', 'instagram', 'youtube')),
    scheduled_for   TIMESTAMPTZ NOT NULL,
    published_at    TIMESTAMPTZ,

    status          TEXT NOT NULL DEFAULT 'queued'
                    CHECK (status IN ('queued', 'processing', 'published', 'failed', 'skipped')),

    platform_post_id    TEXT,
    platform_url        TEXT,

    error_message   TEXT,
    retry_count     INT DEFAULT 0,
    max_retries     INT DEFAULT 3,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_publishing_queue_updated_at
    BEFORE UPDATE ON content_publishing_queue
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_publishing_queue_status ON content_publishing_queue(status);
CREATE INDEX idx_publishing_queue_scheduled ON content_publishing_queue(scheduled_for)
    WHERE status = 'queued';

COMMIT;