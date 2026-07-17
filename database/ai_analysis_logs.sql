USE mindpulse_ai;

CREATE TABLE IF NOT EXISTS ai_analysis_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NULL,
    analysis_type VARCHAR(30) NOT NULL,

    request_summary LONGTEXT NULL,
    response_summary LONGTEXT NULL,

    safety_flagged TINYINT(1) NULL,
    severity VARCHAR(20) NULL,

    risk_score DECIMAL(5,2) NULL,
    risk_level VARCHAR(20) NULL,

    success TINYINT(1) NOT NULL DEFAULT 1,
    error_code VARCHAR(100) NULL,
    processing_time_ms INT UNSIGNED NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    INDEX idx_ai_logs_user (
        user_id
    ),

    INDEX idx_ai_logs_type (
        analysis_type
    ),

    INDEX idx_ai_logs_created (
        created_at
    ),

    INDEX idx_ai_logs_risk (
        risk_level,
        severity
    )
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;
