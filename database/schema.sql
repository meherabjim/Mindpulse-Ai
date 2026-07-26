CREATE DATABASE IF NOT EXISTS mindpulse_ai
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE mindpulse_ai;

-- =====================================================
-- 1. USERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    email VARCHAR(191) NOT NULL,
    phone_number VARCHAR(30) NULL,
    phone_verified_at TIMESTAMP NULL DEFAULT NULL,
    password_hash VARCHAR(255) NOT NULL,

    account_status ENUM(
        'active',
        'suspended',
        'inactive'
    ) NOT NULL DEFAULT 'active',

    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,

    email_verified_at TIMESTAMP NULL DEFAULT NULL,
    last_login_at TIMESTAMP NULL DEFAULT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,

    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT uq_users_phone UNIQUE (phone_number),

    INDEX idx_users_account_status (account_status),
    INDEX idx_users_created_at (created_at),
    INDEX idx_users_deleted_at (deleted_at)
) ENGINE=InnoDB;


-- =====================================================
-- 2. USER PROFILES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    full_name VARCHAR(120) NOT NULL,
    profile_photo_url VARCHAR(500) NULL,

    age_range VARCHAR(30) NULL,
    date_of_birth DATE NULL,
    weight_kg DECIMAL(5,2) NULL,
    height_cm DECIMAL(5,2) NULL,
    usual_water_ml SMALLINT UNSIGNED NULL,
    water_glass_ml SMALLINT UNSIGNED NULL DEFAULT 250,
    typical_sleep_hours DECIMAL(4,2) NULL,
    activity_pattern VARCHAR(40) NULL,
    religion VARCHAR(40) NOT NULL DEFAULT 'prefer_not_to_say',
    religion_other VARCHAR(120) NULL,
    prayer_alarm_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    permission_mode VARCHAR(30) NOT NULL DEFAULT 'choose',

    gender ENUM(
        'male',
        'female',
        'other',
        'prefer_not_to_say'
    ) NULL,

    occupation VARCHAR(120) NULL,

    user_type ENUM(
        'student',
        'employee',
        'self_employed',
        'other'
    ) NULL,

    wellness_goal VARCHAR(150) NULL,

    preferred_language VARCHAR(10) NOT NULL DEFAULT 'en',
    timezone VARCHAR(60) NOT NULL DEFAULT 'Asia/Dhaka',

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_profiles_user_id UNIQUE (user_id),

    CONSTRAINT fk_user_profiles_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB;


-- =====================================================
-- 3. REFRESH TOKENS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    token_hash CHAR(64) NOT NULL,
    expires_at TIMESTAMP NOT NULL,

    revoked_at TIMESTAMP NULL DEFAULT NULL,
    replaced_by_token_hash CHAR(64) NULL,

    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_refresh_tokens_token_hash UNIQUE (token_hash),

    CONSTRAINT fk_refresh_tokens_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    INDEX idx_refresh_tokens_user_id (user_id),
    INDEX idx_refresh_tokens_expires_at (expires_at),
    INDEX idx_refresh_tokens_revoked_at (revoked_at)
) ENGINE=InnoDB;


-- =====================================================
-- VERIFY CREATED TABLES
-- =====================================================
SHOW TABLES;

-- =====================================================
-- 4. PASSWORD RESET TOKENS
-- =====================================================
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,
    used_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_password_reset_token_hash (token_hash),
    INDEX idx_password_reset_user_id (user_id),
    INDEX idx_password_reset_expires_at (expires_at),

    CONSTRAINT fk_password_reset_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 5. USER CONSENTS
-- =====================================================
CREATE TABLE IF NOT EXISTS user_consents (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    consent_type ENUM(
        'terms',
        'privacy',
        'wellness_data',
        'ai_analysis',
        'journal_analysis',
        'analytics',
        'notifications'
    ) NOT NULL,

    is_granted BOOLEAN NOT NULL DEFAULT FALSE,
    policy_version VARCHAR(30) NULL,

    granted_at DATETIME NULL,
    revoked_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_user_consent_type (user_id, consent_type),
    INDEX idx_user_consents_user_id (user_id),

    CONSTRAINT fk_user_consents_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 6. EMERGENCY CONTACTS
-- =====================================================
CREATE TABLE IF NOT EXISTS emergency_contacts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    full_name VARCHAR(120) NOT NULL,
    relationship_name VARCHAR(80) NULL,
    phone_number VARCHAR(30) NOT NULL,
    email VARCHAR(191) NULL,

    is_primary BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_emergency_contacts_user_id (user_id),
    INDEX idx_emergency_contacts_primary (user_id, is_primary),

    CONSTRAINT fk_emergency_contacts_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 7. USER SETTINGS
-- =====================================================
CREATE TABLE IF NOT EXISTS user_settings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    theme_mode ENUM(
        'system',
        'light',
        'dark'
    ) NOT NULL DEFAULT 'system',

    language_code VARCHAR(10) NOT NULL DEFAULT 'en',

    time_format ENUM(
        '12_hour',
        '24_hour'
    ) NOT NULL DEFAULT '12_hour',

    ai_analysis_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    journal_analysis_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    analytics_enabled BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_user_settings_user_id (user_id),

    CONSTRAINT fk_user_settings_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 8. DEVICE TOKENS
-- =====================================================
CREATE TABLE IF NOT EXISTS device_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    token VARCHAR(500) NOT NULL,

    platform ENUM(
        'android',
        'ios',
        'web'
    ) NOT NULL DEFAULT 'android',

    device_name VARCHAR(150) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_used_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_device_tokens_token (token),
    INDEX idx_device_tokens_user_id (user_id),
    INDEX idx_device_tokens_active (user_id, is_active),

    CONSTRAINT fk_device_tokens_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 9. LOGIN ATTEMPTS
-- =====================================================
CREATE TABLE IF NOT EXISTS login_attempts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    email VARCHAR(191) NOT NULL,
    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    was_successful BOOLEAN NOT NULL DEFAULT FALSE,
    failure_reason VARCHAR(150) NULL,

    attempted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_login_attempts_email (email),
    INDEX idx_login_attempts_ip (ip_address),
    INDEX idx_login_attempts_time (attempted_at),
    INDEX idx_login_attempts_success (was_successful)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 10. DAILY CHECK-INS
-- =====================================================
CREATE TABLE IF NOT EXISTS daily_checkins (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    checkin_date DATE NOT NULL,

    mood_score TINYINT UNSIGNED NOT NULL,
    stress_level TINYINT UNSIGNED NOT NULL,
    energy_level TINYINT UNSIGNED NOT NULL,

    sleep_hours DECIMAL(4,2) NULL,
    sleep_quality TINYINT UNSIGNED NULL,

    focus_level TINYINT UNSIGNED NULL,
    motivation_level TINYINT UNSIGNED NULL,
    restlessness_level TINYINT UNSIGNED NULL,

    physical_activity_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    water_intake_glasses TINYINT UNSIGNED NOT NULL DEFAULT 0,
    work_study_pressure TINYINT UNSIGNED NULL,

    note TEXT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_daily_checkin_user_date (user_id, checkin_date),

    INDEX idx_daily_checkins_user_id (user_id),
    INDEX idx_daily_checkins_date (checkin_date),

    CONSTRAINT fk_daily_checkins_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 11. WELLNESS QUESTIONS
-- =====================================================
CREATE TABLE IF NOT EXISTS wellness_questions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    question_code VARCHAR(50) NOT NULL,
    question_text VARCHAR(500) NOT NULL,
    category VARCHAR(80) NOT NULL,

    response_scale ENUM(
        '1_to_5',
        '1_to_10',
        'yes_no'
    ) NOT NULL DEFAULT '1_to_5',

    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_wellness_questions_code (question_code),

    INDEX idx_wellness_questions_category (category),
    INDEX idx_wellness_questions_active (is_active)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 12. WELLNESS SCANS
-- =====================================================
CREATE TABLE IF NOT EXISTS wellness_scans (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    total_score DECIMAL(5,2) NOT NULL,

    risk_level ENUM(
        'low',
        'mild',
        'moderate',
        'elevated'
    ) NOT NULL,

    main_factors TEXT NULL,
    summary TEXT NULL,
    recommendation TEXT NULL,

    completed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_wellness_scans_user_id (user_id),
    INDEX idx_wellness_scans_risk_level (risk_level),
    INDEX idx_wellness_scans_completed_at (completed_at),

    CONSTRAINT fk_wellness_scans_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 13. WELLNESS SCAN ANSWERS
-- =====================================================
CREATE TABLE IF NOT EXISTS wellness_scan_answers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    wellness_scan_id BIGINT UNSIGNED NOT NULL,
    question_id BIGINT UNSIGNED NOT NULL,

    response_value TINYINT UNSIGNED NULL,
    response_text VARCHAR(500) NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_scan_question (
        wellness_scan_id,
        question_id
    ),

    INDEX idx_scan_answers_scan_id (wellness_scan_id),
    INDEX idx_scan_answers_question_id (question_id),

    CONSTRAINT fk_scan_answers_scan
        FOREIGN KEY (wellness_scan_id)
        REFERENCES wellness_scans(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_scan_answers_question
        FOREIGN KEY (question_id)
        REFERENCES wellness_questions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 14. BURNOUT ASSESSMENTS
-- =====================================================
CREATE TABLE IF NOT EXISTS burnout_assessments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    daily_checkin_id BIGINT UNSIGNED NULL,
    wellness_scan_id BIGINT UNSIGNED NULL,

    burnout_score DECIMAL(5,2) NOT NULL,

    risk_level ENUM(
        'low',
        'mild',
        'moderate',
        'elevated'
    ) NOT NULL,

    assessment_source ENUM(
        'checkin',
        'wellness_scan',
        'combined'
    ) NOT NULL DEFAULT 'combined',

    factor_details JSON NULL,
    explanation TEXT NULL,
    algorithm_version VARCHAR(30) NOT NULL DEFAULT '1.0',

    assessed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_burnout_user_id (user_id),
    INDEX idx_burnout_score (burnout_score),
    INDEX idx_burnout_risk_level (risk_level),
    INDEX idx_burnout_assessed_at (assessed_at),

    CONSTRAINT fk_burnout_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_burnout_daily_checkin
        FOREIGN KEY (daily_checkin_id)
        REFERENCES daily_checkins(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_burnout_wellness_scan
        FOREIGN KEY (wellness_scan_id)
        REFERENCES wellness_scans(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 15. JOURNALS
-- =====================================================
CREATE TABLE IF NOT EXISTS journals (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    title VARCHAR(180) NULL,
    content MEDIUMTEXT NOT NULL,
    entry_date DATE NOT NULL,

    mood_score TINYINT UNSIGNED NULL,
    is_private BOOLEAN NOT NULL DEFAULT TRUE,
    is_favorite BOOLEAN NOT NULL DEFAULT FALSE,

    analysis_status ENUM(
        'not_requested',
        'pending',
        'completed',
        'failed'
    ) NOT NULL DEFAULT 'not_requested',

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,

    INDEX idx_journals_user_id (user_id),
    INDEX idx_journals_entry_date (entry_date),
    INDEX idx_journals_favorite (user_id, is_favorite),
    INDEX idx_journals_deleted_at (deleted_at),

    CONSTRAINT fk_journals_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 16. JOURNAL TAGS
-- =====================================================
CREATE TABLE IF NOT EXISTS journal_tags (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    name VARCHAR(60) NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_journal_tag_user_name (user_id, name),
    INDEX idx_journal_tags_user_id (user_id),

    CONSTRAINT fk_journal_tags_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 17. JOURNAL TAG MAPPINGS
-- =====================================================
CREATE TABLE IF NOT EXISTS journal_tag_mappings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    journal_id BIGINT UNSIGNED NOT NULL,
    tag_id BIGINT UNSIGNED NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_journal_tag_mapping (journal_id, tag_id),
    INDEX idx_tag_mappings_journal_id (journal_id),
    INDEX idx_tag_mappings_tag_id (tag_id),

    CONSTRAINT fk_tag_mappings_journal
        FOREIGN KEY (journal_id)
        REFERENCES journals(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_tag_mappings_tag
        FOREIGN KEY (tag_id)
        REFERENCES journal_tags(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 18. JOURNAL ANALYSES
-- =====================================================
CREATE TABLE IF NOT EXISTS journal_analyses (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    journal_id BIGINT UNSIGNED NOT NULL,

    sentiment_label ENUM(
        'positive',
        'neutral',
        'negative',
        'mixed'
    ) NOT NULL,

    sentiment_score DECIMAL(6,4) NULL,

    stress_level ENUM(
        'low',
        'mild',
        'moderate',
        'elevated'
    ) NULL,

    emotional_themes JSON NULL,
    summary TEXT NULL,
    reflection_prompt TEXT NULL,

    safety_flag BOOLEAN NOT NULL DEFAULT FALSE,
    safety_category VARCHAR(100) NULL,

    model_version VARCHAR(50) NOT NULL DEFAULT '1.0',
    analyzed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_journal_analysis_journal_id (journal_id),
    INDEX idx_journal_analysis_sentiment (sentiment_label),
    INDEX idx_journal_analysis_safety (safety_flag),

    CONSTRAINT fk_journal_analysis_journal
        FOREIGN KEY (journal_id)
        REFERENCES journals(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 19. HABIT TEMPLATES
-- =====================================================
CREATE TABLE IF NOT EXISTS habit_templates (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    name VARCHAR(120) NOT NULL,
    category VARCHAR(80) NOT NULL,
    description VARCHAR(500) NULL,
    icon_name VARCHAR(100) NULL,

    default_target_value DECIMAL(8,2) NULL,
    default_unit VARCHAR(40) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_habit_templates_name (name),
    INDEX idx_habit_templates_category (category),
    INDEX idx_habit_templates_active (is_active)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 20. HABITS
-- =====================================================
CREATE TABLE IF NOT EXISTS habits (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    template_id BIGINT UNSIGNED NULL,

    name VARCHAR(120) NOT NULL,
    description VARCHAR(500) NULL,
    category VARCHAR(80) NOT NULL,

    frequency_type ENUM(
        'daily',
        'specific_days',
        'weekly'
    ) NOT NULL DEFAULT 'daily',

    schedule_days JSON NULL,

    target_value DECIMAL(8,2) NOT NULL DEFAULT 1,
    unit VARCHAR(40) NULL,

    reminder_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    reminder_time TIME NULL,

    start_date DATE NOT NULL,
    end_date DATE NULL,

    current_streak INT UNSIGNED NOT NULL DEFAULT 0,
    longest_streak INT UNSIGNED NOT NULL DEFAULT 0,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,

    INDEX idx_habits_user_id (user_id),
    INDEX idx_habits_template_id (template_id),
    INDEX idx_habits_active (user_id, is_active),
    INDEX idx_habits_archived (user_id, is_archived),

    CONSTRAINT fk_habits_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_habits_template
        FOREIGN KEY (template_id)
        REFERENCES habit_templates(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 21. HABIT LOGS
-- =====================================================
CREATE TABLE IF NOT EXISTS habit_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    habit_id BIGINT UNSIGNED NOT NULL,

    log_date DATE NOT NULL,

    status ENUM(
        'pending',
        'completed',
        'skipped'
    ) NOT NULL DEFAULT 'pending',

    completed_value DECIMAL(8,2) NULL,
    note VARCHAR(500) NULL,
    completed_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_habit_log_date (habit_id, log_date),

    INDEX idx_habit_logs_habit_id (habit_id),
    INDEX idx_habit_logs_date (log_date),
    INDEX idx_habit_logs_status (status),

    CONSTRAINT fk_habit_logs_habit
        FOREIGN KEY (habit_id)
        REFERENCES habits(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 22. RECOVERY ACTIVITIES
-- =====================================================
CREATE TABLE IF NOT EXISTS recovery_activities (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    title VARCHAR(150) NOT NULL,
    slug VARCHAR(160) NOT NULL,

    category ENUM(
        'breathing',
        'relaxation',
        'meditation',
        'grounding',
        'stretching',
        'sleep',
        'focus',
        'reflection',
        'digital_break',
        'physical_activity'
    ) NOT NULL,

    description VARCHAR(1000) NULL,
    instructions MEDIUMTEXT NOT NULL,

    duration_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 5,

    difficulty_level ENUM(
        'beginner',
        'intermediate'
    ) NOT NULL DEFAULT 'beginner',

    icon_name VARCHAR(100) NULL,
    audio_url VARCHAR(500) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_recovery_activities_slug (slug),

    INDEX idx_recovery_activities_category (category),
    INDEX idx_recovery_activities_active (is_active),
    INDEX idx_recovery_activities_order (display_order)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 23. RECOVERY ACTIVITY LOGS
-- =====================================================
CREATE TABLE IF NOT EXISTS recovery_activity_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,
    recovery_activity_id BIGINT UNSIGNED NOT NULL,

    status ENUM(
        'started',
        'completed',
        'cancelled'
    ) NOT NULL DEFAULT 'started',

    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,

    duration_seconds INT UNSIGNED NULL,
    rating TINYINT UNSIGNED NULL,
    note VARCHAR(500) NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_recovery_logs_user_id (user_id),
    INDEX idx_recovery_logs_activity_id (recovery_activity_id),
    INDEX idx_recovery_logs_status (status),
    INDEX idx_recovery_logs_started_at (started_at),

    CONSTRAINT fk_recovery_logs_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_recovery_logs_activity
        FOREIGN KEY (recovery_activity_id)
        REFERENCES recovery_activities(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 24. RECOVERY PLANS
-- =====================================================
CREATE TABLE IF NOT EXISTS recovery_plans (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,

    title VARCHAR(180) NOT NULL,
    description TEXT NULL,
    overall_goal VARCHAR(500) NULL,

    generated_by ENUM(
        'rule_based',
        'ai',
        'manual'
    ) NOT NULL DEFAULT 'rule_based',

    status ENUM(
        'active',
        'completed',
        'paused',
        'cancelled'
    ) NOT NULL DEFAULT 'active',

    start_date DATE NOT NULL,
    end_date DATE NULL,
    review_date DATE NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_recovery_plans_user_id (user_id),
    INDEX idx_recovery_plans_status (user_id, status),
    INDEX idx_recovery_plans_start_date (start_date),

    CONSTRAINT fk_recovery_plans_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 25. RECOVERY PLAN TASKS
-- =====================================================
CREATE TABLE IF NOT EXISTS recovery_plan_tasks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    recovery_plan_id BIGINT UNSIGNED NOT NULL,
    recovery_activity_id BIGINT UNSIGNED NULL,

    title VARCHAR(180) NOT NULL,
    description VARCHAR(1000) NULL,

    task_type ENUM(
        'sleep',
        'hydration',
        'habit',
        'recovery_activity',
        'journal',
        'physical_activity',
        'custom'
    ) NOT NULL,

    target_value DECIMAL(8,2) NULL,
    target_unit VARCHAR(50) NULL,

    scheduled_date DATE NOT NULL,
    scheduled_time TIME NULL,

    status ENUM(
        'pending',
        'completed',
        'skipped',
        'rescheduled'
    ) NOT NULL DEFAULT 'pending',

    completed_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_recovery_tasks_plan_id (recovery_plan_id),
    INDEX idx_recovery_tasks_activity_id (recovery_activity_id),
    INDEX idx_recovery_tasks_date (scheduled_date),
    INDEX idx_recovery_tasks_status (status),

    CONSTRAINT fk_recovery_tasks_plan
        FOREIGN KEY (recovery_plan_id)
        REFERENCES recovery_plans(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_recovery_tasks_activity
        FOREIGN KEY (recovery_activity_id)
        REFERENCES recovery_activities(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 26. RECOVERY PROGRESS
-- =====================================================
CREATE TABLE IF NOT EXISTS recovery_progress (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,
    recovery_plan_id BIGINT UNSIGNED NULL,

    progress_date DATE NOT NULL,

    mood_score DECIMAL(5,2) NULL,
    stress_score DECIMAL(5,2) NULL,
    sleep_hours DECIMAL(4,2) NULL,
    energy_level DECIMAL(5,2) NULL,

    habit_completion_percent DECIMAL(5,2) NULL,
    activity_completion_percent DECIMAL(5,2) NULL,

    burnout_score DECIMAL(5,2) NULL,
    recovery_score DECIMAL(5,2) NOT NULL,

    note VARCHAR(1000) NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_recovery_progress_user_date (
        user_id,
        progress_date
    ),

    INDEX idx_recovery_progress_user_id (user_id),
    INDEX idx_recovery_progress_plan_id (recovery_plan_id),
    INDEX idx_recovery_progress_date (progress_date),
    INDEX idx_recovery_progress_score (recovery_score),

    CONSTRAINT fk_recovery_progress_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_recovery_progress_plan
        FOREIGN KEY (recovery_plan_id)
        REFERENCES recovery_plans(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 27. AI CONVERSATIONS
-- =====================================================
CREATE TABLE IF NOT EXISTS ai_conversations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,

    title VARCHAR(180) NULL,

    status ENUM(
        'active',
        'archived',
        'closed'
    ) NOT NULL DEFAULT 'active',

    last_message_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,

    INDEX idx_ai_conversations_user_id (user_id),
    INDEX idx_ai_conversations_status (user_id, status),
    INDEX idx_ai_conversations_last_message (last_message_at),
    INDEX idx_ai_conversations_deleted_at (deleted_at),

    CONSTRAINT fk_ai_conversations_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 28. AI MESSAGES
-- =====================================================
CREATE TABLE IF NOT EXISTS ai_messages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    conversation_id BIGINT UNSIGNED NOT NULL,

    message_role ENUM(
        'user',
        'assistant',
        'system'
    ) NOT NULL,

    content MEDIUMTEXT NOT NULL,

    safety_flag BOOLEAN NOT NULL DEFAULT FALSE,
    safety_category VARCHAR(100) NULL,

    model_name VARCHAR(100) NULL,
    response_time_ms INT UNSIGNED NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_ai_messages_conversation_id (conversation_id),
    INDEX idx_ai_messages_role (message_role),
    INDEX idx_ai_messages_safety (safety_flag),
    INDEX idx_ai_messages_created_at (created_at),

    CONSTRAINT fk_ai_messages_conversation
        FOREIGN KEY (conversation_id)
        REFERENCES ai_conversations(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 29. AI RECOMMENDATIONS
-- =====================================================
CREATE TABLE IF NOT EXISTS ai_recommendations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,

    daily_checkin_id BIGINT UNSIGNED NULL,
    wellness_scan_id BIGINT UNSIGNED NULL,
    burnout_assessment_id BIGINT UNSIGNED NULL,

    recommendation_type ENUM(
        'daily',
        'recovery',
        'sleep',
        'habit',
        'stress',
        'focus',
        'journal',
        'safety'
    ) NOT NULL,

    title VARCHAR(180) NOT NULL,
    content MEDIUMTEXT NOT NULL,

    priority_level ENUM(
        'low',
        'normal',
        'high',
        'urgent'
    ) NOT NULL DEFAULT 'normal',

    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    is_dismissed BOOLEAN NOT NULL DEFAULT FALSE,

    valid_until DATETIME NULL,
    model_version VARCHAR(50) NOT NULL DEFAULT '1.0',

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_ai_recommendations_user_id (user_id),
    INDEX idx_ai_recommendations_type (recommendation_type),
    INDEX idx_ai_recommendations_priority (priority_level),
    INDEX idx_ai_recommendations_read (user_id, is_read),
    INDEX idx_ai_recommendations_created_at (created_at),

    CONSTRAINT fk_ai_recommendations_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_ai_recommendations_checkin
        FOREIGN KEY (daily_checkin_id)
        REFERENCES daily_checkins(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_ai_recommendations_scan
        FOREIGN KEY (wellness_scan_id)
        REFERENCES wellness_scans(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_ai_recommendations_burnout
        FOREIGN KEY (burnout_assessment_id)
        REFERENCES burnout_assessments(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 30. AI SAFETY EVENTS
-- =====================================================
CREATE TABLE IF NOT EXISTS ai_safety_events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,
    conversation_id BIGINT UNSIGNED NULL,
    message_id BIGINT UNSIGNED NULL,

    event_type ENUM(
        'self_harm',
        'crisis',
        'severe_distress',
        'abuse',
        'medical_emergency',
        'other'
    ) NOT NULL,

    severity_level ENUM(
        'low',
        'moderate',
        'high',
        'critical'
    ) NOT NULL,

    matched_terms JSON NULL,
    redacted_excerpt VARCHAR(500) NULL,
    action_taken TEXT NULL,

    emergency_contact_shown BOOLEAN NOT NULL DEFAULT FALSE,

    review_status ENUM(
        'unreviewed',
        'reviewed',
        'false_positive'
    ) NOT NULL DEFAULT 'unreviewed',

    reviewed_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_ai_safety_user_id (user_id),
    INDEX idx_ai_safety_conversation_id (conversation_id),
    INDEX idx_ai_safety_message_id (message_id),
    INDEX idx_ai_safety_severity (severity_level),
    INDEX idx_ai_safety_review_status (review_status),
    INDEX idx_ai_safety_created_at (created_at),

    CONSTRAINT fk_ai_safety_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_ai_safety_conversation
        FOREIGN KEY (conversation_id)
        REFERENCES ai_conversations(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_ai_safety_message
        FOREIGN KEY (message_id)
        REFERENCES ai_messages(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 31. LEVELS
-- =====================================================
CREATE TABLE IF NOT EXISTS levels (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL,
    icon_name VARCHAR(100) NULL,

    minimum_points INT UNSIGNED NOT NULL DEFAULT 0,
    maximum_points INT UNSIGNED NULL,

    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_levels_name (name),
    INDEX idx_levels_points (minimum_points, maximum_points),
    INDEX idx_levels_active (is_active),
    INDEX idx_levels_display_order (display_order)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 32. BADGES
-- =====================================================
CREATE TABLE IF NOT EXISTS badges (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    badge_code VARCHAR(80) NOT NULL,
    name VARCHAR(120) NOT NULL,
    description VARCHAR(500) NULL,

    category ENUM(
        'checkin',
        'habit',
        'journal',
        'recovery',
        'wellness',
        'sleep',
        'hydration',
        'activity',
        'consistency',
        'special'
    ) NOT NULL,

    criteria_type VARCHAR(100) NOT NULL,
    criteria_value DECIMAL(10,2) NOT NULL DEFAULT 1,

    points_reward INT UNSIGNED NOT NULL DEFAULT 0,
    icon_name VARCHAR(100) NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_badges_code (badge_code),
    UNIQUE KEY uq_badges_name (name),

    INDEX idx_badges_category (category),
    INDEX idx_badges_active (is_active),
    INDEX idx_badges_display_order (display_order)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 33. USER LEVELS
-- =====================================================
CREATE TABLE IF NOT EXISTS user_levels (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,
    level_id BIGINT UNSIGNED NOT NULL,

    total_points INT UNSIGNED NOT NULL DEFAULT 0,
    achieved_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_user_levels_user_id (user_id),

    INDEX idx_user_levels_level_id (level_id),
    INDEX idx_user_levels_points (total_points),

    CONSTRAINT fk_user_levels_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_user_levels_level
        FOREIGN KEY (level_id)
        REFERENCES levels(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 34. USER BADGES
-- =====================================================
CREATE TABLE IF NOT EXISTS user_badges (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,
    badge_id BIGINT UNSIGNED NOT NULL,

    earned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    points_awarded INT UNSIGNED NOT NULL DEFAULT 0,

    criteria_snapshot JSON NULL,
    source_reference_type VARCHAR(80) NULL,
    source_reference_id BIGINT UNSIGNED NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_user_badges_user_badge (
        user_id,
        badge_id
    ),

    INDEX idx_user_badges_user_id (user_id),
    INDEX idx_user_badges_badge_id (badge_id),
    INDEX idx_user_badges_earned_at (earned_at),

    CONSTRAINT fk_user_badges_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_user_badges_badge
        FOREIGN KEY (badge_id)
        REFERENCES badges(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 35. ACHIEVEMENT PROGRESS
-- =====================================================
CREATE TABLE IF NOT EXISTS achievement_progress (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,
    badge_id BIGINT UNSIGNED NOT NULL,

    current_value DECIMAL(10,2) NOT NULL DEFAULT 0,
    target_value DECIMAL(10,2) NOT NULL,

    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at DATETIME NULL,
    last_progress_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_achievement_progress_user_badge (
        user_id,
        badge_id
    ),

    INDEX idx_achievement_progress_user_id (user_id),
    INDEX idx_achievement_progress_badge_id (badge_id),
    INDEX idx_achievement_progress_completed (is_completed),

    CONSTRAINT fk_achievement_progress_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_achievement_progress_badge
        FOREIGN KEY (badge_id)
        REFERENCES badges(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 36. ADMIN USERS
-- =====================================================
CREATE TABLE IF NOT EXISTS admin_users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(191) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,

    role ENUM(
        'super_admin',
        'admin',
        'content_manager',
        'analyst'
    ) NOT NULL DEFAULT 'admin',

    account_status ENUM(
        'active',
        'suspended',
        'inactive'
    ) NOT NULL DEFAULT 'active',

    last_login_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,

    UNIQUE KEY uq_admin_users_email (email),

    INDEX idx_admin_users_role (role),
    INDEX idx_admin_users_status (account_status),
    INDEX idx_admin_users_deleted_at (deleted_at)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 37. NOTIFICATION PREFERENCES
-- =====================================================
CREATE TABLE IF NOT EXISTS notification_preferences (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,

    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    checkin_reminders BOOLEAN NOT NULL DEFAULT TRUE,
    habit_reminders BOOLEAN NOT NULL DEFAULT TRUE,
    sleep_reminders BOOLEAN NOT NULL DEFAULT TRUE,
    recovery_reminders BOOLEAN NOT NULL DEFAULT TRUE,
    wellness_scan_reminders BOOLEAN NOT NULL DEFAULT TRUE,
    report_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    achievement_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    inactivity_reminders BOOLEAN NOT NULL DEFAULT TRUE,
    announcement_notifications BOOLEAN NOT NULL DEFAULT TRUE,

    quiet_hours_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    quiet_hours_start TIME NULL,
    quiet_hours_end TIME NULL,

    timezone VARCHAR(60) NOT NULL DEFAULT 'Asia/Dhaka',

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_notification_preferences_user_id (user_id),

    CONSTRAINT fk_notification_preferences_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 38. NOTIFICATION TEMPLATES
-- =====================================================
CREATE TABLE IF NOT EXISTS notification_templates (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    template_code VARCHAR(100) NOT NULL,

    notification_type ENUM(
        'checkin_reminder',
        'habit_reminder',
        'sleep_reminder',
        'recovery_reminder',
        'wellness_scan_reminder',
        'report_ready',
        'achievement',
        'inactivity',
        'announcement',
        'system'
    ) NOT NULL,

    title_template VARCHAR(200) NOT NULL,
    body_template VARCHAR(1000) NOT NULL,

    available_variables JSON NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_notification_templates_code (template_code),

    INDEX idx_notification_templates_type (notification_type),
    INDEX idx_notification_templates_active (is_active)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 39. NOTIFICATIONS
-- =====================================================
CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NOT NULL,
    template_id BIGINT UNSIGNED NULL,
    created_by_admin_id BIGINT UNSIGNED NULL,

    notification_type ENUM(
        'checkin_reminder',
        'habit_reminder',
        'sleep_reminder',
        'recovery_reminder',
        'wellness_scan_reminder',
        'report_ready',
        'achievement',
        'inactivity',
        'announcement',
        'system'
    ) NOT NULL,

    title VARCHAR(200) NOT NULL,
    body VARCHAR(1000) NOT NULL,

    priority_level ENUM(
        'low',
        'normal',
        'high'
    ) NOT NULL DEFAULT 'normal',

    data_payload JSON NULL,

    status ENUM(
        'pending',
        'scheduled',
        'sent',
        'delivered',
        'failed',
        'read',
        'cancelled'
    ) NOT NULL DEFAULT 'pending',

    scheduled_at DATETIME NULL,
    sent_at DATETIME NULL,
    delivered_at DATETIME NULL,
    read_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_notifications_user_id (user_id),
    INDEX idx_notifications_template_id (template_id),
    INDEX idx_notifications_admin_id (created_by_admin_id),
    INDEX idx_notifications_status (status),
    INDEX idx_notifications_type (notification_type),
    INDEX idx_notifications_scheduled_at (scheduled_at),
    INDEX idx_notifications_read_at (user_id, read_at),

    CONSTRAINT fk_notifications_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_notifications_template
        FOREIGN KEY (template_id)
        REFERENCES notification_templates(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_notifications_admin
        FOREIGN KEY (created_by_admin_id)
        REFERENCES admin_users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 40. NOTIFICATION LOGS
-- =====================================================
CREATE TABLE IF NOT EXISTS notification_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    notification_id BIGINT UNSIGNED NOT NULL,
    device_token_id BIGINT UNSIGNED NULL,

    delivery_status ENUM(
        'queued',
        'sent',
        'delivered',
        'failed'
    ) NOT NULL DEFAULT 'queued',

    provider_message_id VARCHAR(255) NULL,
    attempt_number TINYINT UNSIGNED NOT NULL DEFAULT 1,
    error_message VARCHAR(1000) NULL,

    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivered_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_notification_logs_notification_id (notification_id),
    INDEX idx_notification_logs_device_token_id (device_token_id),
    INDEX idx_notification_logs_status (delivery_status),
    INDEX idx_notification_logs_attempted_at (attempted_at),

    CONSTRAINT fk_notification_logs_notification
        FOREIGN KEY (notification_id)
        REFERENCES notifications(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_notification_logs_device_token
        FOREIGN KEY (device_token_id)
        REFERENCES device_tokens(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 41. EMAIL VERIFICATION TOKENS
-- =====================================================
CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,
    verified_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_email_verification_token_hash (token_hash),

    INDEX idx_email_verification_user_id (user_id),
    INDEX idx_email_verification_expires_at (expires_at),

    CONSTRAINT fk_email_verification_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 42. ADMIN REFRESH TOKENS
-- =====================================================
CREATE TABLE IF NOT EXISTS admin_refresh_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    admin_user_id BIGINT UNSIGNED NOT NULL,

    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,

    revoked_at DATETIME NULL,
    replaced_by_token_hash CHAR(64) NULL,

    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_admin_refresh_token_hash (token_hash),

    INDEX idx_admin_refresh_admin_id (admin_user_id),
    INDEX idx_admin_refresh_expires_at (expires_at),
    INDEX idx_admin_refresh_revoked_at (revoked_at),

    CONSTRAINT fk_admin_refresh_admin
        FOREIGN KEY (admin_user_id)
        REFERENCES admin_users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 43. ADMIN LOGIN ATTEMPTS
-- =====================================================
CREATE TABLE IF NOT EXISTS admin_login_attempts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    admin_user_id BIGINT UNSIGNED NULL,
    email VARCHAR(191) NOT NULL,

    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    was_successful BOOLEAN NOT NULL DEFAULT FALSE,
    failure_reason VARCHAR(150) NULL,

    attempted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_admin_login_admin_id (admin_user_id),
    INDEX idx_admin_login_email (email),
    INDEX idx_admin_login_ip (ip_address),
    INDEX idx_admin_login_time (attempted_at),
    INDEX idx_admin_login_success (was_successful),

    CONSTRAINT fk_admin_login_admin
        FOREIGN KEY (admin_user_id)
        REFERENCES admin_users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 44. REPORTS
-- =====================================================
CREATE TABLE IF NOT EXISTS reports (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,

    report_type ENUM(
        'weekly',
        'monthly',
        'burnout',
        'habit',
        'sleep',
        'recovery',
        'custom'
    ) NOT NULL,

    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    status ENUM(
        'pending',
        'generating',
        'completed',
        'failed'
    ) NOT NULL DEFAULT 'pending',

    summary MEDIUMTEXT NULL,
    metrics JSON NULL,
    recommendations MEDIUMTEXT NULL,

    generated_by ENUM(
        'system',
        'ai',
        'manual'
    ) NOT NULL DEFAULT 'system',

    algorithm_version VARCHAR(50) NULL,
    generated_at DATETIME NULL,
    failure_reason VARCHAR(1000) NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_reports_user_id (user_id),
    INDEX idx_reports_type (report_type),
    INDEX idx_reports_status (status),
    INDEX idx_reports_period (period_start, period_end),
    INDEX idx_reports_created_at (created_at),

    CONSTRAINT fk_reports_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 45. REPORT FILES
-- =====================================================
CREATE TABLE IF NOT EXISTS report_files (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    report_id BIGINT UNSIGNED NOT NULL,

    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(1000) NOT NULL,

    mime_type VARCHAR(100) NOT NULL DEFAULT 'application/pdf',
    file_size_bytes BIGINT UNSIGNED NULL,

    storage_type ENUM(
        'local',
        'cloud'
    ) NOT NULL DEFAULT 'local',

    checksum_sha256 CHAR(64) NULL,
    expires_at DATETIME NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_report_files_report_id (report_id),
    INDEX idx_report_files_storage_type (storage_type),
    INDEX idx_report_files_expires_at (expires_at),

    CONSTRAINT fk_report_files_report
        FOREIGN KEY (report_id)
        REFERENCES reports(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 46. USER DATA REQUESTS
-- =====================================================
CREATE TABLE IF NOT EXISTS user_data_requests (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NULL,
    requested_email VARCHAR(191) NOT NULL,

    request_type ENUM(
        'data_export',
        'account_deletion'
    ) NOT NULL,

    status ENUM(
        'pending',
        'processing',
        'completed',
        'rejected',
        'cancelled'
    ) NOT NULL DEFAULT 'pending',

    reason VARCHAR(1000) NULL,

    export_file_path VARCHAR(1000) NULL,
    export_expires_at DATETIME NULL,

    processed_by_admin_id BIGINT UNSIGNED NULL,
    processed_at DATETIME NULL,
    rejection_reason VARCHAR(1000) NULL,

    requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_data_requests_user_id (user_id),
    INDEX idx_data_requests_email (requested_email),
    INDEX idx_data_requests_type (request_type),
    INDEX idx_data_requests_status (status),
    INDEX idx_data_requests_requested_at (requested_at),
    INDEX idx_data_requests_admin_id (processed_by_admin_id),

    CONSTRAINT fk_data_requests_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_data_requests_admin
        FOREIGN KEY (processed_by_admin_id)
        REFERENCES admin_users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 47. AUDIT LOGS
-- =====================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    user_id BIGINT UNSIGNED NULL,
    admin_user_id BIGINT UNSIGNED NULL,

    actor_type ENUM(
        'user',
        'admin',
        'system'
    ) NOT NULL,

    action VARCHAR(150) NOT NULL,

    entity_type VARCHAR(100) NULL,
    entity_id BIGINT UNSIGNED NULL,

    old_values JSON NULL,
    new_values JSON NULL,
    metadata JSON NULL,

    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(500) NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_audit_logs_user_id (user_id),
    INDEX idx_audit_logs_admin_id (admin_user_id),
    INDEX idx_audit_logs_actor_type (actor_type),
    INDEX idx_audit_logs_action (action),
    INDEX idx_audit_logs_entity (entity_type, entity_id),
    INDEX idx_audit_logs_created_at (created_at),

    CONSTRAINT fk_audit_logs_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_audit_logs_admin
        FOREIGN KEY (admin_user_id)
        REFERENCES admin_users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 48. SYSTEM LOGS
-- =====================================================
CREATE TABLE IF NOT EXISTS system_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    log_level ENUM(
        'debug',
        'info',
        'warning',
        'error',
        'critical'
    ) NOT NULL DEFAULT 'info',

    service_name ENUM(
        'backend',
        'ai_service',
        'database',
        'notification',
        'admin_dashboard',
        'mobile_app',
        'other'
    ) NOT NULL,

    event_code VARCHAR(100) NULL,
    message VARCHAR(2000) NOT NULL,

    context_data JSON NULL,
    stack_trace MEDIUMTEXT NULL,

    request_id VARCHAR(100) NULL,
    occurred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_system_logs_level (log_level),
    INDEX idx_system_logs_service (service_name),
    INDEX idx_system_logs_event_code (event_code),
    INDEX idx_system_logs_request_id (request_id),
    INDEX idx_system_logs_occurred_at (occurred_at)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 49. APP CONTENTS
-- =====================================================
CREATE TABLE IF NOT EXISTS app_contents (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    content_key VARCHAR(150) NOT NULL,

    content_type ENUM(
        'terms',
        'privacy_policy',
        'wellness_disclaimer',
        'onboarding',
        'help',
        'about',
        'announcement',
        'emergency_guidance',
        'other'
    ) NOT NULL,

    title VARCHAR(255) NOT NULL,
    content MEDIUMTEXT NOT NULL,

    version VARCHAR(30) NOT NULL DEFAULT '1.0',
    language_code VARCHAR(10) NOT NULL DEFAULT 'en',

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    published_at DATETIME NULL,

    updated_by_admin_id BIGINT UNSIGNED NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_app_contents_key_version_language (
        content_key,
        version,
        language_code
    ),

    INDEX idx_app_contents_type (content_type),
    INDEX idx_app_contents_active (is_active),
    INDEX idx_app_contents_language (language_code),
    INDEX idx_app_contents_admin_id (updated_by_admin_id),

    CONSTRAINT fk_app_contents_admin
        FOREIGN KEY (updated_by_admin_id)
        REFERENCES admin_users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 50. SUPPORT RESOURCES
-- =====================================================
CREATE TABLE IF NOT EXISTS support_resources (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    country_code CHAR(2) NOT NULL,
    region_name VARCHAR(120) NULL,

    resource_type ENUM(
        'emergency_service',
        'crisis_hotline',
        'professional_support',
        'mental_health_service',
        'trusted_contact_guidance',
        'other'
    ) NOT NULL,

    name VARCHAR(200) NOT NULL,
    description VARCHAR(1000) NULL,

    phone_number VARCHAR(50) NULL,
    website_url VARCHAR(1000) NULL,
    availability_text VARCHAR(255) NULL,

    supported_languages JSON NULL,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,

    updated_by_admin_id BIGINT UNSIGNED NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_support_resources_country (country_code),
    INDEX idx_support_resources_region (region_name),
    INDEX idx_support_resources_type (resource_type),
    INDEX idx_support_resources_active (is_active),
    INDEX idx_support_resources_order (display_order),

    CONSTRAINT fk_support_resources_admin
        FOREIGN KEY (updated_by_admin_id)
        REFERENCES admin_users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;

