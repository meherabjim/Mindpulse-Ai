-- MINDPULSE FIRST LOGIN FAITH PERMISSIONS V2
USE mindpulse_ai;

SET @schema_name = DATABASE();

SET @sql = IF(
    EXISTS(
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = @schema_name
          AND TABLE_NAME = 'user_profiles'
          AND COLUMN_NAME = 'typical_sleep_hours'
    ),
    'SELECT 1',
    'ALTER TABLE user_profiles ADD COLUMN typical_sleep_hours DECIMAL(4,2) NULL AFTER water_glass_ml'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME='user_profiles' AND COLUMN_NAME='activity_pattern'),
    'SELECT 1',
    'ALTER TABLE user_profiles ADD COLUMN activity_pattern VARCHAR(40) NULL AFTER typical_sleep_hours'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME='user_profiles' AND COLUMN_NAME='religion'),
    'SELECT 1',
    "ALTER TABLE user_profiles ADD COLUMN religion VARCHAR(40) NOT NULL DEFAULT 'prefer_not_to_say' AFTER activity_pattern"
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME='user_profiles' AND COLUMN_NAME='religion_other'),
    'SELECT 1',
    'ALTER TABLE user_profiles ADD COLUMN religion_other VARCHAR(120) NULL AFTER religion'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME='user_profiles' AND COLUMN_NAME='prayer_alarm_enabled'),
    'SELECT 1',
    'ALTER TABLE user_profiles ADD COLUMN prayer_alarm_enabled BOOLEAN NOT NULL DEFAULT FALSE AFTER religion_other'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF(
    EXISTS(SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME='user_profiles' AND COLUMN_NAME='permission_mode'),
    'SELECT 1',
    "ALTER TABLE user_profiles ADD COLUMN permission_mode VARCHAR(30) NOT NULL DEFAULT 'choose' AFTER prayer_alarm_enabled"
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
