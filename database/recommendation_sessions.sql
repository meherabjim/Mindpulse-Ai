CREATE TABLE IF NOT EXISTS recommendation_sessions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    user_id BIGINT UNSIGNED NOT NULL,

    client_session_key VARCHAR(80) NOT NULL,

    recommendation_source VARCHAR(40)
        NOT NULL DEFAULT 'ai_wellness',

    recommendation_category VARCHAR(60)
        NOT NULL,

    recommendation_title VARCHAR(180)
        NOT NULL,

    recommendation_action VARCHAR(1500)
        NOT NULL,

    priority_level ENUM(
        'low',
        'medium',
        'high'
    ) NOT NULL DEFAULT 'medium',

    suggested_duration_seconds
        INT UNSIGNED NOT NULL,

    actual_duration_seconds
        INT UNSIGNED NOT NULL DEFAULT 0,

    status ENUM(
        'started',
        'completed',
        'abandoned',
        'remind_later'
    ) NOT NULL DEFAULT 'started',

    before_mood TINYINT UNSIGNED NULL,
    before_stress TINYINT UNSIGNED NULL,

    after_mood TINYINT UNSIGNED NULL,
    after_stress TINYINT UNSIGNED NULL,

    feedback_type ENUM(
        'helpful',
        'neutral',
        'not_useful'
    ) NULL,

    feedback_note VARCHAR(500) NULL,

    tracking_source ENUM(
        'in_app_timer',
        'self_report'
    ) NOT NULL DEFAULT 'in_app_timer',

    started_at DATETIME
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    ended_at DATETIME NULL,

    created_at DATETIME
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at DATETIME
        NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    UNIQUE KEY
        uq_recommendation_session_client (
            user_id,
            client_session_key
        ),

    KEY
        idx_recommendation_session_user_date (
            user_id,
            started_at
        ),

    KEY
        idx_recommendation_session_user_status (
            user_id,
            status
        ),

    KEY
        idx_recommendation_session_category (
            recommendation_category
        ),

    CONSTRAINT
        fk_recommendation_session_user

        FOREIGN KEY (user_id)
        REFERENCES users (id)
        ON DELETE CASCADE
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_unicode_ci;
