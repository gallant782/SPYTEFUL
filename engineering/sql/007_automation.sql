-- ============================================================
-- MindFrame Database Schema — Migration 007: Automation Tables
-- ============================================================

BEGIN;

-- ============================
-- Automation Workflows Registry
-- ============================
CREATE TABLE automation_workflows (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    description     TEXT,

    platform        TEXT NOT NULL CHECK (platform IN ('n8n', 'make', 'zapier', 'custom')),
    workflow_json   JSONB,
    external_id     TEXT,

    category        TEXT NOT NULL
                    CHECK (category IN (
                        'content_publishing', 'email_marketing', 'lead_capture',
                        'payment_processing', 'analytics', 'affiliate', 'community',
                        'monitoring', 'data_sync', 'onboarding', 'retention'
                    )),

    trigger_type    TEXT,
    cron_expression TEXT,

    is_active       BOOLEAN DEFAULT TRUE,
    last_run_at     TIMESTAMPTZ,
    last_run_status TEXT,

    alert_email     TEXT,
    max_retries     INT DEFAULT 3,

    version         INT DEFAULT 1,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_automation_workflows_updated_at
    BEFORE UPDATE ON automation_workflows
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_automation_workflows_category ON automation_workflows(category);
CREATE INDEX idx_automation_workflows_active ON automation_workflows(is_active) WHERE is_active = TRUE;

-- ============================
-- Automation Execution Logs
-- ============================
CREATE TABLE automation_execution_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    workflow_id     UUID NOT NULL REFERENCES automation_workflows(id) ON DELETE CASCADE,
    execution_id    TEXT,

    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,

    status          TEXT NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'success', 'failed', 'timeout', 'cancelled')),
    error_message   TEXT,
    error_stack     TEXT,

    input_data      JSONB,
    output_data     JSONB,

    trigger_source  TEXT,
    trigger_detail  JSONB DEFAULT '{}'::jsonb,

    -- Related entity IDs for linking
    related_video_id        UUID,
    related_subscriber_id   UUID,
    related_purchase_id     UUID,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_automation_logs_workflow ON automation_execution_logs(workflow_id);
CREATE INDEX idx_automation_logs_status ON automation_execution_logs(status);
CREATE INDEX idx_automation_logs_started ON automation_execution_logs(started_at);
CREATE INDEX idx_automation_logs_failed ON automation_execution_logs(workflow_id, started_at DESC)
    WHERE status = 'failed';

COMMIT;