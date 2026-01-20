-- Community Seed Content Automation System
-- Database Schema for PostgreSQL

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Topics Table: Stores discovered topics from various sources
CREATE TABLE community_topics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    hook TEXT,
    source VARCHAR(100),
    source_url TEXT,
    content_type VARCHAR(50) CHECK (content_type IN ('article', 'discussion', 'question', 'hot-take')),
    discussion_angle VARCHAR(50) CHECK (discussion_angle IN ('contrarian', 'practical', 'personal')),
    controversy_level INT DEFAULT 3 CHECK (controversy_level BETWEEN 1 AND 5),
    complexity VARCHAR(20) CHECK (complexity IN ('beginner', 'intermediate', 'advanced')),
    expertise_tags TEXT[], -- Array of expertise areas
    status VARCHAR(20) DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'drafted', 'scheduled', 'posted', 'failed')),
    priority INT DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Index for querying queued topics
CREATE INDEX idx_topics_status ON community_topics(status);
CREATE INDEX idx_topics_created_at ON community_topics(created_at DESC);
CREATE INDEX idx_topics_expertise ON community_topics USING GIN(expertise_tags);

-- Posts Table: Stores generated content
CREATE TABLE community_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    topic_id UUID REFERENCES community_topics(id) ON DELETE SET NULL,
    persona_id VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    original_content TEXT, -- Before humanization
    platform_post_id VARCHAR(100), -- ID from community platform
    scheduled_for TIMESTAMP WITH TIME ZONE,
    posted_at TIMESTAMP WITH TIME ZONE,
    ai_detection_score INT DEFAULT 0,
    ai_detection_grade VARCHAR(10),
    humanization_applied JSONB DEFAULT '{}'::jsonb, -- Track what was changed
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'humanizing', 'scheduled', 'posting', 'posted', 'failed', 'rewrite_needed')),
    retry_count INT DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for posts
CREATE INDEX idx_posts_status ON community_posts(status);
CREATE INDEX idx_posts_persona ON community_posts(persona_id);
CREATE INDEX idx_posts_scheduled ON community_posts(scheduled_for) WHERE status = 'scheduled';
CREATE INDEX idx_posts_topic ON community_posts(topic_id);

-- Engagements Table: Stores comments and reactions
CREATE TABLE community_engagements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE,
    engager_persona_id VARCHAR(50) NOT NULL,
    engagement_type VARCHAR(20) CHECK (engagement_type IN ('comment', 'reaction', 'reply')),
    comment_type VARCHAR(20) CHECK (comment_type IN ('agreement', 'pushback', 'question', 'experience')),
    content TEXT,
    platform_engagement_id VARCHAR(100),
    delay_minutes INT,
    scheduled_for TIMESTAMP WITH TIME ZONE,
    executed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'scheduled', 'executing', 'completed', 'failed')),
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for engagements
CREATE INDEX idx_engagements_post ON community_engagements(post_id);
CREATE INDEX idx_engagements_scheduled ON community_engagements(scheduled_for) WHERE status = 'scheduled';
CREATE INDEX idx_engagements_persona ON community_engagements(engager_persona_id);

-- Seed Accounts Table: Maps personas to platform accounts
CREATE TABLE community_seed_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    persona_id VARCHAR(50) UNIQUE NOT NULL,
    platform_user_id VARCHAR(100) NOT NULL,
    platform_username VARCHAR(100),
    api_token_encrypted TEXT, -- Should be encrypted at application level
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'retired', 'banned')),
    post_count INT DEFAULT 0,
    engagement_count INT DEFAULT 0,
    last_post_at TIMESTAMP WITH TIME ZONE,
    last_engagement_at TIMESTAMP WITH TIME ZONE,
    rate_limit_reset_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for seed accounts
CREATE INDEX idx_seed_accounts_status ON community_seed_accounts(status);

-- Rate Limiting Table: Track activity for rate limiting
CREATE TABLE community_rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    persona_id VARCHAR(50) NOT NULL,
    action_type VARCHAR(20) NOT NULL CHECK (action_type IN ('post', 'comment', 'reaction')),
    action_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Index for rate limit queries
CREATE INDEX idx_rate_limits_persona_time ON community_rate_limits(persona_id, action_timestamp DESC);
CREATE INDEX idx_rate_limits_action_time ON community_rate_limits(action_type, action_timestamp DESC);

-- Workflow Logs Table: Track workflow executions
CREATE TABLE community_workflow_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_name VARCHAR(100) NOT NULL,
    workflow_execution_id VARCHAR(100),
    status VARCHAR(20) CHECK (status IN ('started', 'completed', 'failed', 'warning')),
    items_processed INT DEFAULT 0,
    error_message TEXT,
    duration_ms INT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for workflow logs
CREATE INDEX idx_workflow_logs_name ON community_workflow_logs(workflow_name);
CREATE INDEX idx_workflow_logs_created ON community_workflow_logs(created_at DESC);

-- Analytics Table: Daily summaries
CREATE TABLE community_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE NOT NULL,
    persona_id VARCHAR(50),
    posts_created INT DEFAULT 0,
    posts_published INT DEFAULT 0,
    engagements_created INT DEFAULT 0,
    engagements_executed INT DEFAULT 0,
    avg_ai_detection_score DECIMAL(5,2),
    rewrites_needed INT DEFAULT 0,
    failures INT DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(date, persona_id)
);

-- Index for analytics
CREATE INDEX idx_analytics_date ON community_analytics(date DESC);

-- Helper function: Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE ON community_posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_seed_accounts_updated_at
    BEFORE UPDATE ON community_seed_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- View: Recent activity summary
CREATE OR REPLACE VIEW community_recent_activity AS
SELECT
    'post' as activity_type,
    p.persona_id,
    p.status,
    p.created_at,
    p.content as preview
FROM community_posts p
WHERE p.created_at > NOW() - INTERVAL '24 hours'
UNION ALL
SELECT
    'engagement' as activity_type,
    e.engager_persona_id as persona_id,
    e.status,
    e.created_at,
    e.content as preview
FROM community_engagements e
WHERE e.created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- View: Persona stats
CREATE OR REPLACE VIEW community_persona_stats AS
SELECT
    sa.persona_id,
    sa.status,
    sa.post_count,
    sa.engagement_count,
    sa.last_post_at,
    sa.last_engagement_at,
    COUNT(DISTINCT p.id) FILTER (WHERE p.status = 'posted' AND p.posted_at > NOW() - INTERVAL '7 days') as posts_last_week,
    COUNT(DISTINCT e.id) FILTER (WHERE e.status = 'completed' AND e.executed_at > NOW() - INTERVAL '7 days') as engagements_last_week,
    AVG(p.ai_detection_score) FILTER (WHERE p.ai_detection_score IS NOT NULL) as avg_detection_score
FROM community_seed_accounts sa
LEFT JOIN community_posts p ON sa.persona_id = p.persona_id
LEFT JOIN community_engagements e ON sa.persona_id = e.engager_persona_id
GROUP BY sa.persona_id, sa.status, sa.post_count, sa.engagement_count, sa.last_post_at, sa.last_engagement_at;

-- Function: Check rate limits
CREATE OR REPLACE FUNCTION check_rate_limit(
    p_persona_id VARCHAR(50),
    p_action_type VARCHAR(20),
    p_limit_per_hour INT,
    p_limit_per_day INT
) RETURNS TABLE(
    allowed BOOLEAN,
    wait_minutes INT,
    reason TEXT
) AS $$
DECLARE
    hourly_count INT;
    daily_count INT;
BEGIN
    -- Count actions in last hour
    SELECT COUNT(*) INTO hourly_count
    FROM community_rate_limits
    WHERE persona_id = p_persona_id
      AND action_type = p_action_type
      AND action_timestamp > NOW() - INTERVAL '1 hour';

    -- Count actions in last 24 hours
    SELECT COUNT(*) INTO daily_count
    FROM community_rate_limits
    WHERE persona_id = p_persona_id
      AND action_type = p_action_type
      AND action_timestamp > NOW() - INTERVAL '24 hours';

    -- Check limits
    IF hourly_count >= p_limit_per_hour THEN
        RETURN QUERY SELECT FALSE, 60 - EXTRACT(MINUTE FROM NOW())::INT, 'Hourly limit reached';
    ELSIF daily_count >= p_limit_per_day THEN
        RETURN QUERY SELECT FALSE,
            EXTRACT(EPOCH FROM (DATE_TRUNC('day', NOW()) + INTERVAL '1 day' - NOW()) / 60)::INT,
            'Daily limit reached';
    ELSE
        RETURN QUERY SELECT TRUE, 0, NULL::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Sample data for testing (optional - comment out in production)
/*
INSERT INTO community_seed_accounts (persona_id, platform_user_id, platform_username, status) VALUES
('alex_founder', 'user_alex_001', 'alexchen_founder', 'active'),
('dev_sam', 'user_sam_002', 'samrivera_dev', 'active'),
('pm_jordan', 'user_jordan_003', 'jordanpark_pm', 'active'),
('indie_maya', 'user_maya_004', 'mayathompson_indie', 'active'),
('design_kai', 'user_kai_005', 'kainakamura_design', 'active');
*/
