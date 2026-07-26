-- MindPulse registration and first-login body profile migration
-- Safe for existing installations. Existing users remain nullable.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS phone_number VARCHAR(30) NULL AFTER email,
    ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMP NULL DEFAULT NULL AFTER phone_number;

ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS date_of_birth DATE NULL AFTER age_range,
    ADD COLUMN IF NOT EXISTS weight_kg DECIMAL(5,2) NULL AFTER date_of_birth,
    ADD COLUMN IF NOT EXISTS height_cm DECIMAL(5,2) NULL AFTER weight_kg,
    ADD COLUMN IF NOT EXISTS usual_water_ml SMALLINT UNSIGNED NULL AFTER height_cm,
    ADD COLUMN IF NOT EXISTS water_glass_ml SMALLINT UNSIGNED NULL DEFAULT 250 AFTER usual_water_ml;

SET @phone_index_exists = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = 'users'
      AND index_name = 'uq_users_phone'
);

SET @phone_index_sql = IF(
    @phone_index_exists = 0,
    'ALTER TABLE users ADD UNIQUE KEY uq_users_phone (phone_number)',
    'SELECT 1'
);

PREPARE phone_index_statement FROM @phone_index_sql;
EXECUTE phone_index_statement;
DEALLOCATE PREPARE phone_index_statement;
