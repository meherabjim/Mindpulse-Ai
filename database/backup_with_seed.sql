-- MariaDB dump 10.19  Distrib 10.4.32-MariaDB, for Win64 (AMD64)
--
-- Host: localhost    Database: mindpulse_ai
-- ------------------------------------------------------
-- Server version	10.4.32-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `achievement_progress`
--

DROP TABLE IF EXISTS `achievement_progress`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `achievement_progress` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `badge_id` bigint(20) unsigned NOT NULL,
  `current_value` decimal(10,2) NOT NULL DEFAULT 0.00,
  `target_value` decimal(10,2) NOT NULL,
  `is_completed` tinyint(1) NOT NULL DEFAULT 0,
  `completed_at` datetime DEFAULT NULL,
  `last_progress_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_achievement_progress_user_badge` (`user_id`,`badge_id`),
  KEY `idx_achievement_progress_user_id` (`user_id`),
  KEY `idx_achievement_progress_badge_id` (`badge_id`),
  KEY `idx_achievement_progress_completed` (`is_completed`),
  CONSTRAINT `fk_achievement_progress_badge` FOREIGN KEY (`badge_id`) REFERENCES `badges` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_achievement_progress_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `achievement_progress`
--

LOCK TABLES `achievement_progress` WRITE;
/*!40000 ALTER TABLE `achievement_progress` DISABLE KEYS */;
/*!40000 ALTER TABLE `achievement_progress` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `admin_login_attempts`
--

DROP TABLE IF EXISTS `admin_login_attempts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_login_attempts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `admin_user_id` bigint(20) unsigned DEFAULT NULL,
  `email` varchar(191) NOT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(500) DEFAULT NULL,
  `was_successful` tinyint(1) NOT NULL DEFAULT 0,
  `failure_reason` varchar(150) DEFAULT NULL,
  `attempted_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_admin_login_admin_id` (`admin_user_id`),
  KEY `idx_admin_login_email` (`email`),
  KEY `idx_admin_login_ip` (`ip_address`),
  KEY `idx_admin_login_time` (`attempted_at`),
  KEY `idx_admin_login_success` (`was_successful`),
  CONSTRAINT `fk_admin_login_admin` FOREIGN KEY (`admin_user_id`) REFERENCES `admin_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_login_attempts`
--

LOCK TABLES `admin_login_attempts` WRITE;
/*!40000 ALTER TABLE `admin_login_attempts` DISABLE KEYS */;
/*!40000 ALTER TABLE `admin_login_attempts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `admin_refresh_tokens`
--

DROP TABLE IF EXISTS `admin_refresh_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_refresh_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `admin_user_id` bigint(20) unsigned NOT NULL,
  `token_hash` char(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `replaced_by_token_hash` char(64) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_admin_refresh_token_hash` (`token_hash`),
  KEY `idx_admin_refresh_admin_id` (`admin_user_id`),
  KEY `idx_admin_refresh_expires_at` (`expires_at`),
  KEY `idx_admin_refresh_revoked_at` (`revoked_at`),
  CONSTRAINT `fk_admin_refresh_admin` FOREIGN KEY (`admin_user_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_refresh_tokens`
--

LOCK TABLES `admin_refresh_tokens` WRITE;
/*!40000 ALTER TABLE `admin_refresh_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `admin_refresh_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `admin_users`
--

DROP TABLE IF EXISTS `admin_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `full_name` varchar(120) NOT NULL,
  `email` varchar(191) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('super_admin','admin','content_manager','analyst') NOT NULL DEFAULT 'admin',
  `account_status` enum('active','suspended','inactive') NOT NULL DEFAULT 'active',
  `last_login_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_admin_users_email` (`email`),
  KEY `idx_admin_users_role` (`role`),
  KEY `idx_admin_users_status` (`account_status`),
  KEY `idx_admin_users_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_users`
--

LOCK TABLES `admin_users` WRITE;
/*!40000 ALTER TABLE `admin_users` DISABLE KEYS */;
/*!40000 ALTER TABLE `admin_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ai_conversations`
--

DROP TABLE IF EXISTS `ai_conversations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ai_conversations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `title` varchar(180) DEFAULT NULL,
  `status` enum('active','archived','closed') NOT NULL DEFAULT 'active',
  `last_message_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ai_conversations_user_id` (`user_id`),
  KEY `idx_ai_conversations_status` (`user_id`,`status`),
  KEY `idx_ai_conversations_last_message` (`last_message_at`),
  KEY `idx_ai_conversations_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_ai_conversations_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_conversations`
--

LOCK TABLES `ai_conversations` WRITE;
/*!40000 ALTER TABLE `ai_conversations` DISABLE KEYS */;
/*!40000 ALTER TABLE `ai_conversations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ai_messages`
--

DROP TABLE IF EXISTS `ai_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ai_messages` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `conversation_id` bigint(20) unsigned NOT NULL,
  `message_role` enum('user','assistant','system') NOT NULL,
  `content` mediumtext NOT NULL,
  `safety_flag` tinyint(1) NOT NULL DEFAULT 0,
  `safety_category` varchar(100) DEFAULT NULL,
  `model_name` varchar(100) DEFAULT NULL,
  `response_time_ms` int(10) unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ai_messages_conversation_id` (`conversation_id`),
  KEY `idx_ai_messages_role` (`message_role`),
  KEY `idx_ai_messages_safety` (`safety_flag`),
  KEY `idx_ai_messages_created_at` (`created_at`),
  CONSTRAINT `fk_ai_messages_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `ai_conversations` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_messages`
--

LOCK TABLES `ai_messages` WRITE;
/*!40000 ALTER TABLE `ai_messages` DISABLE KEYS */;
/*!40000 ALTER TABLE `ai_messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ai_recommendations`
--

DROP TABLE IF EXISTS `ai_recommendations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ai_recommendations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `daily_checkin_id` bigint(20) unsigned DEFAULT NULL,
  `wellness_scan_id` bigint(20) unsigned DEFAULT NULL,
  `burnout_assessment_id` bigint(20) unsigned DEFAULT NULL,
  `recommendation_type` enum('daily','recovery','sleep','habit','stress','focus','journal','safety') NOT NULL,
  `title` varchar(180) NOT NULL,
  `content` mediumtext NOT NULL,
  `priority_level` enum('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  `is_read` tinyint(1) NOT NULL DEFAULT 0,
  `is_dismissed` tinyint(1) NOT NULL DEFAULT 0,
  `valid_until` datetime DEFAULT NULL,
  `model_version` varchar(50) NOT NULL DEFAULT '1.0',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ai_recommendations_user_id` (`user_id`),
  KEY `idx_ai_recommendations_type` (`recommendation_type`),
  KEY `idx_ai_recommendations_priority` (`priority_level`),
  KEY `idx_ai_recommendations_read` (`user_id`,`is_read`),
  KEY `idx_ai_recommendations_created_at` (`created_at`),
  KEY `fk_ai_recommendations_checkin` (`daily_checkin_id`),
  KEY `fk_ai_recommendations_scan` (`wellness_scan_id`),
  KEY `fk_ai_recommendations_burnout` (`burnout_assessment_id`),
  CONSTRAINT `fk_ai_recommendations_burnout` FOREIGN KEY (`burnout_assessment_id`) REFERENCES `burnout_assessments` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_ai_recommendations_checkin` FOREIGN KEY (`daily_checkin_id`) REFERENCES `daily_checkins` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_ai_recommendations_scan` FOREIGN KEY (`wellness_scan_id`) REFERENCES `wellness_scans` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_ai_recommendations_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_recommendations`
--

LOCK TABLES `ai_recommendations` WRITE;
/*!40000 ALTER TABLE `ai_recommendations` DISABLE KEYS */;
/*!40000 ALTER TABLE `ai_recommendations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ai_safety_events`
--

DROP TABLE IF EXISTS `ai_safety_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ai_safety_events` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `conversation_id` bigint(20) unsigned DEFAULT NULL,
  `message_id` bigint(20) unsigned DEFAULT NULL,
  `event_type` enum('self_harm','crisis','severe_distress','abuse','medical_emergency','other') NOT NULL,
  `severity_level` enum('low','moderate','high','critical') NOT NULL,
  `matched_terms` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`matched_terms`)),
  `redacted_excerpt` varchar(500) DEFAULT NULL,
  `action_taken` text DEFAULT NULL,
  `emergency_contact_shown` tinyint(1) NOT NULL DEFAULT 0,
  `review_status` enum('unreviewed','reviewed','false_positive') NOT NULL DEFAULT 'unreviewed',
  `reviewed_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ai_safety_user_id` (`user_id`),
  KEY `idx_ai_safety_conversation_id` (`conversation_id`),
  KEY `idx_ai_safety_message_id` (`message_id`),
  KEY `idx_ai_safety_severity` (`severity_level`),
  KEY `idx_ai_safety_review_status` (`review_status`),
  KEY `idx_ai_safety_created_at` (`created_at`),
  CONSTRAINT `fk_ai_safety_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `ai_conversations` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_ai_safety_message` FOREIGN KEY (`message_id`) REFERENCES `ai_messages` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_ai_safety_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_safety_events`
--

LOCK TABLES `ai_safety_events` WRITE;
/*!40000 ALTER TABLE `ai_safety_events` DISABLE KEYS */;
/*!40000 ALTER TABLE `ai_safety_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `app_contents`
--

DROP TABLE IF EXISTS `app_contents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `app_contents` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `content_key` varchar(150) NOT NULL,
  `content_type` enum('terms','privacy_policy','wellness_disclaimer','onboarding','help','about','announcement','emergency_guidance','other') NOT NULL,
  `title` varchar(255) NOT NULL,
  `content` mediumtext NOT NULL,
  `version` varchar(30) NOT NULL DEFAULT '1.0',
  `language_code` varchar(10) NOT NULL DEFAULT 'en',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `published_at` datetime DEFAULT NULL,
  `updated_by_admin_id` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_app_contents_key_version_language` (`content_key`,`version`,`language_code`),
  KEY `idx_app_contents_type` (`content_type`),
  KEY `idx_app_contents_active` (`is_active`),
  KEY `idx_app_contents_language` (`language_code`),
  KEY `idx_app_contents_admin_id` (`updated_by_admin_id`),
  CONSTRAINT `fk_app_contents_admin` FOREIGN KEY (`updated_by_admin_id`) REFERENCES `admin_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `app_contents`
--

LOCK TABLES `app_contents` WRITE;
/*!40000 ALTER TABLE `app_contents` DISABLE KEYS */;
INSERT INTO `app_contents` VALUES (1,'wellness_disclaimer','wellness_disclaimer','Wellness Disclaimer','MindPulse AI is a wellness-support application. It does not provide medical diagnosis, professional psychological treatment, emergency response, or medication advice. Users should seek qualified professional support when necessary.','1.0','en',1,'2026-07-11 17:05:13',NULL,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(2,'about_mindpulse','about','About MindPulse AI','MindPulse AI helps users record wellness information, understand personal trends, develop healthy habits, and follow supportive recovery activities.','1.0','en',1,'2026-07-11 17:05:13',NULL,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(3,'privacy_policy_draft','privacy_policy','Privacy Policy Draft','This is a demonstration privacy policy for the MindPulse AI academic project. A complete production privacy policy must be reviewed before public deployment.','1.0','en',0,NULL,NULL,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(4,'terms_draft','terms','Terms and Conditions Draft','These demonstration terms are provided for the MindPulse AI academic project. Final legal terms must be reviewed before public deployment.','1.0','en',0,NULL,NULL,'2026-07-11 11:05:13','2026-07-11 11:05:13');
/*!40000 ALTER TABLE `app_contents` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `audit_logs`
--

DROP TABLE IF EXISTS `audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `audit_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `admin_user_id` bigint(20) unsigned DEFAULT NULL,
  `actor_type` enum('user','admin','system') NOT NULL,
  `action` varchar(150) NOT NULL,
  `entity_type` varchar(100) DEFAULT NULL,
  `entity_id` bigint(20) unsigned DEFAULT NULL,
  `old_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`old_values`)),
  `new_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`new_values`)),
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`metadata`)),
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_audit_logs_user_id` (`user_id`),
  KEY `idx_audit_logs_admin_id` (`admin_user_id`),
  KEY `idx_audit_logs_actor_type` (`actor_type`),
  KEY `idx_audit_logs_action` (`action`),
  KEY `idx_audit_logs_entity` (`entity_type`,`entity_id`),
  KEY `idx_audit_logs_created_at` (`created_at`),
  CONSTRAINT `fk_audit_logs_admin` FOREIGN KEY (`admin_user_id`) REFERENCES `admin_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_audit_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `audit_logs`
--

LOCK TABLES `audit_logs` WRITE;
/*!40000 ALTER TABLE `audit_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `audit_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `badges`
--

DROP TABLE IF EXISTS `badges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `badges` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `badge_code` varchar(80) NOT NULL,
  `name` varchar(120) NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `category` enum('checkin','habit','journal','recovery','wellness','sleep','hydration','activity','consistency','special') NOT NULL,
  `criteria_type` varchar(100) NOT NULL,
  `criteria_value` decimal(10,2) NOT NULL DEFAULT 1.00,
  `points_reward` int(10) unsigned NOT NULL DEFAULT 0,
  `icon_name` varchar(100) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `display_order` smallint(5) unsigned NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_badges_code` (`badge_code`),
  UNIQUE KEY `uq_badges_name` (`name`),
  KEY `idx_badges_category` (`category`),
  KEY `idx_badges_active` (`is_active`),
  KEY `idx_badges_display_order` (`display_order`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `badges`
--

LOCK TABLES `badges` WRITE;
/*!40000 ALTER TABLE `badges` DISABLE KEYS */;
INSERT INTO `badges` VALUES (1,'FIRST_CHECKIN','First Check-in','Complete the first daily wellness check-in.','checkin','total_checkins',1.00,10,'badge_first_checkin',1,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(2,'CHECKIN_7_DAY','7-Day Check-in','Complete daily check-ins for seven consecutive days.','checkin','checkin_streak',7.00,30,'badge_checkin_7',1,2,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(3,'CHECKIN_30_DAY','30-Day Check-in','Complete daily check-ins for thirty consecutive days.','consistency','checkin_streak',30.00,100,'badge_checkin_30',1,3,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(4,'WATER_HERO','Water Hero','Achieve the daily hydration target seven times.','hydration','hydration_target_days',7.00,25,'badge_water_hero',1,4,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(5,'SLEEP_CHAMPION','Sleep Champion','Meet the healthy sleep target seven times.','sleep','sleep_target_days',7.00,25,'badge_sleep_champion',1,5,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(6,'CALM_MIND','Calm Mind','Complete ten breathing, meditation, or grounding activities.','recovery','calm_activity_count',10.00,40,'badge_calm_mind',1,6,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(7,'JOURNAL_STREAK','Journal Streak','Write journal entries for seven consecutive days.','journal','journal_streak',7.00,35,'badge_journal_streak',1,7,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(8,'ACTIVE_WALKER','Active Walker','Complete ten walking or physical activity habits.','activity','walking_completion_count',10.00,30,'badge_active_walker',1,8,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(9,'HABIT_BUILDER','Habit Builder','Complete twenty-five habit logs.','habit','habit_completion_count',25.00,50,'badge_habit_builder',1,9,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(10,'RECOVERY_MILESTONE','Recovery Milestone','Reach seventy-five percent recovery progress.','recovery','recovery_score',75.00,60,'badge_recovery_milestone',1,10,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(11,'WELLNESS_EXPLORER','Wellness Explorer','Complete five detailed wellness scans.','wellness','wellness_scan_count',5.00,30,'badge_wellness_explorer',1,11,'2026-07-11 11:05:13','2026-07-11 11:05:13');
/*!40000 ALTER TABLE `badges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `burnout_assessments`
--

DROP TABLE IF EXISTS `burnout_assessments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `burnout_assessments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `daily_checkin_id` bigint(20) unsigned DEFAULT NULL,
  `wellness_scan_id` bigint(20) unsigned DEFAULT NULL,
  `burnout_score` decimal(5,2) NOT NULL,
  `risk_level` enum('low','mild','moderate','elevated') NOT NULL,
  `assessment_source` enum('checkin','wellness_scan','combined') NOT NULL DEFAULT 'combined',
  `factor_details` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`factor_details`)),
  `explanation` text DEFAULT NULL,
  `algorithm_version` varchar(30) NOT NULL DEFAULT '1.0',
  `assessed_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_burnout_user_id` (`user_id`),
  KEY `idx_burnout_score` (`burnout_score`),
  KEY `idx_burnout_risk_level` (`risk_level`),
  KEY `idx_burnout_assessed_at` (`assessed_at`),
  KEY `fk_burnout_daily_checkin` (`daily_checkin_id`),
  KEY `fk_burnout_wellness_scan` (`wellness_scan_id`),
  CONSTRAINT `fk_burnout_daily_checkin` FOREIGN KEY (`daily_checkin_id`) REFERENCES `daily_checkins` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_burnout_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_burnout_wellness_scan` FOREIGN KEY (`wellness_scan_id`) REFERENCES `wellness_scans` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `burnout_assessments`
--

LOCK TABLES `burnout_assessments` WRITE;
/*!40000 ALTER TABLE `burnout_assessments` DISABLE KEYS */;
/*!40000 ALTER TABLE `burnout_assessments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `daily_checkins`
--

DROP TABLE IF EXISTS `daily_checkins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `daily_checkins` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `checkin_date` date NOT NULL,
  `mood_score` tinyint(3) unsigned NOT NULL,
  `stress_level` tinyint(3) unsigned NOT NULL,
  `energy_level` tinyint(3) unsigned NOT NULL,
  `sleep_hours` decimal(4,2) DEFAULT NULL,
  `sleep_quality` tinyint(3) unsigned DEFAULT NULL,
  `focus_level` tinyint(3) unsigned DEFAULT NULL,
  `motivation_level` tinyint(3) unsigned DEFAULT NULL,
  `restlessness_level` tinyint(3) unsigned DEFAULT NULL,
  `physical_activity_minutes` smallint(5) unsigned NOT NULL DEFAULT 0,
  `water_intake_glasses` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `work_study_pressure` tinyint(3) unsigned DEFAULT NULL,
  `note` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_daily_checkin_user_date` (`user_id`,`checkin_date`),
  KEY `idx_daily_checkins_user_id` (`user_id`),
  KEY `idx_daily_checkins_date` (`checkin_date`),
  CONSTRAINT `fk_daily_checkins_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `daily_checkins`
--

LOCK TABLES `daily_checkins` WRITE;
/*!40000 ALTER TABLE `daily_checkins` DISABLE KEYS */;
/*!40000 ALTER TABLE `daily_checkins` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `device_tokens`
--

DROP TABLE IF EXISTS `device_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `device_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `token` varchar(500) NOT NULL,
  `platform` enum('android','ios','web') NOT NULL DEFAULT 'android',
  `device_name` varchar(150) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `last_used_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_device_tokens_token` (`token`),
  KEY `idx_device_tokens_user_id` (`user_id`),
  KEY `idx_device_tokens_active` (`user_id`,`is_active`),
  CONSTRAINT `fk_device_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `device_tokens`
--

LOCK TABLES `device_tokens` WRITE;
/*!40000 ALTER TABLE `device_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `device_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `email_verification_tokens`
--

DROP TABLE IF EXISTS `email_verification_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `email_verification_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `token_hash` char(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `verified_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_email_verification_token_hash` (`token_hash`),
  KEY `idx_email_verification_user_id` (`user_id`),
  KEY `idx_email_verification_expires_at` (`expires_at`),
  CONSTRAINT `fk_email_verification_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `email_verification_tokens`
--

LOCK TABLES `email_verification_tokens` WRITE;
/*!40000 ALTER TABLE `email_verification_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `email_verification_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emergency_contacts`
--

DROP TABLE IF EXISTS `emergency_contacts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `emergency_contacts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `full_name` varchar(120) NOT NULL,
  `relationship_name` varchar(80) DEFAULT NULL,
  `phone_number` varchar(30) NOT NULL,
  `email` varchar(191) DEFAULT NULL,
  `is_primary` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_emergency_contacts_user_id` (`user_id`),
  KEY `idx_emergency_contacts_primary` (`user_id`,`is_primary`),
  CONSTRAINT `fk_emergency_contacts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emergency_contacts`
--

LOCK TABLES `emergency_contacts` WRITE;
/*!40000 ALTER TABLE `emergency_contacts` DISABLE KEYS */;
/*!40000 ALTER TABLE `emergency_contacts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `habit_logs`
--

DROP TABLE IF EXISTS `habit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `habit_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `habit_id` bigint(20) unsigned NOT NULL,
  `log_date` date NOT NULL,
  `status` enum('pending','completed','skipped') NOT NULL DEFAULT 'pending',
  `completed_value` decimal(8,2) DEFAULT NULL,
  `note` varchar(500) DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_habit_log_date` (`habit_id`,`log_date`),
  KEY `idx_habit_logs_habit_id` (`habit_id`),
  KEY `idx_habit_logs_date` (`log_date`),
  KEY `idx_habit_logs_status` (`status`),
  CONSTRAINT `fk_habit_logs_habit` FOREIGN KEY (`habit_id`) REFERENCES `habits` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `habit_logs`
--

LOCK TABLES `habit_logs` WRITE;
/*!40000 ALTER TABLE `habit_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `habit_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `habit_templates`
--

DROP TABLE IF EXISTS `habit_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `habit_templates` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(120) NOT NULL,
  `category` varchar(80) NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `icon_name` varchar(100) DEFAULT NULL,
  `default_target_value` decimal(8,2) DEFAULT NULL,
  `default_unit` varchar(40) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `display_order` smallint(5) unsigned NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_habit_templates_name` (`name`),
  KEY `idx_habit_templates_category` (`category`),
  KEY `idx_habit_templates_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `habit_templates`
--

LOCK TABLES `habit_templates` WRITE;
/*!40000 ALTER TABLE `habit_templates` DISABLE KEYS */;
INSERT INTO `habit_templates` VALUES (1,'Drink Water','hydration','Maintain regular water intake throughout the day.','water_drop',8.00,'glasses',1,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(2,'Healthy Sleep','sleep','Maintain a consistent and healthy sleep routine.','bedtime',8.00,'hours',1,2,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(3,'Daily Walk','walking','Take a short walk to support physical and emotional wellness.','directions_walk',20.00,'minutes',1,3,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(4,'Meditation','meditation','Practice a short mindfulness or meditation activity.','self_improvement',10.00,'minutes',1,4,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(5,'Exercise','exercise','Complete a light or moderate physical exercise session.','fitness_center',20.00,'minutes',1,5,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(6,'Write Journal','journaling','Write a short reflection about the day.','menu_book',1.00,'entry',1,6,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(7,'Screen Break','digital_wellness','Take regular breaks from phones and computer screens.','phonelink_off',3.00,'breaks',1,7,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(8,'Read a Book','reading','Spend a short period reading something meaningful.','auto_stories',15.00,'minutes',1,8,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(9,'Healthy Meal','nutrition','Complete the daily healthy meal goal.','restaurant',2.00,'meals',1,9,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(10,'Breathing Exercise','breathing','Complete a short calming breathing exercise.','air',5.00,'minutes',1,10,'2026-07-11 11:05:13','2026-07-11 11:05:13');
/*!40000 ALTER TABLE `habit_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `habits`
--

DROP TABLE IF EXISTS `habits`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `habits` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `template_id` bigint(20) unsigned DEFAULT NULL,
  `name` varchar(120) NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `category` varchar(80) NOT NULL,
  `frequency_type` enum('daily','specific_days','weekly') NOT NULL DEFAULT 'daily',
  `schedule_days` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`schedule_days`)),
  `target_value` decimal(8,2) NOT NULL DEFAULT 1.00,
  `unit` varchar(40) DEFAULT NULL,
  `reminder_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `reminder_time` time DEFAULT NULL,
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL,
  `current_streak` int(10) unsigned NOT NULL DEFAULT 0,
  `longest_streak` int(10) unsigned NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `is_archived` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_habits_user_id` (`user_id`),
  KEY `idx_habits_template_id` (`template_id`),
  KEY `idx_habits_active` (`user_id`,`is_active`),
  KEY `idx_habits_archived` (`user_id`,`is_archived`),
  CONSTRAINT `fk_habits_template` FOREIGN KEY (`template_id`) REFERENCES `habit_templates` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_habits_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `habits`
--

LOCK TABLES `habits` WRITE;
/*!40000 ALTER TABLE `habits` DISABLE KEYS */;
/*!40000 ALTER TABLE `habits` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `journal_analyses`
--

DROP TABLE IF EXISTS `journal_analyses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `journal_analyses` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `journal_id` bigint(20) unsigned NOT NULL,
  `sentiment_label` enum('positive','neutral','negative','mixed') NOT NULL,
  `sentiment_score` decimal(6,4) DEFAULT NULL,
  `stress_level` enum('low','mild','moderate','elevated') DEFAULT NULL,
  `emotional_themes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`emotional_themes`)),
  `summary` text DEFAULT NULL,
  `reflection_prompt` text DEFAULT NULL,
  `safety_flag` tinyint(1) NOT NULL DEFAULT 0,
  `safety_category` varchar(100) DEFAULT NULL,
  `model_version` varchar(50) NOT NULL DEFAULT '1.0',
  `analyzed_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_journal_analysis_journal_id` (`journal_id`),
  KEY `idx_journal_analysis_sentiment` (`sentiment_label`),
  KEY `idx_journal_analysis_safety` (`safety_flag`),
  CONSTRAINT `fk_journal_analysis_journal` FOREIGN KEY (`journal_id`) REFERENCES `journals` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `journal_analyses`
--

LOCK TABLES `journal_analyses` WRITE;
/*!40000 ALTER TABLE `journal_analyses` DISABLE KEYS */;
/*!40000 ALTER TABLE `journal_analyses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `journal_tag_mappings`
--

DROP TABLE IF EXISTS `journal_tag_mappings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `journal_tag_mappings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `journal_id` bigint(20) unsigned NOT NULL,
  `tag_id` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_journal_tag_mapping` (`journal_id`,`tag_id`),
  KEY `idx_tag_mappings_journal_id` (`journal_id`),
  KEY `idx_tag_mappings_tag_id` (`tag_id`),
  CONSTRAINT `fk_tag_mappings_journal` FOREIGN KEY (`journal_id`) REFERENCES `journals` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tag_mappings_tag` FOREIGN KEY (`tag_id`) REFERENCES `journal_tags` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `journal_tag_mappings`
--

LOCK TABLES `journal_tag_mappings` WRITE;
/*!40000 ALTER TABLE `journal_tag_mappings` DISABLE KEYS */;
/*!40000 ALTER TABLE `journal_tag_mappings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `journal_tags`
--

DROP TABLE IF EXISTS `journal_tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `journal_tags` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `name` varchar(60) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_journal_tag_user_name` (`user_id`,`name`),
  KEY `idx_journal_tags_user_id` (`user_id`),
  CONSTRAINT `fk_journal_tags_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `journal_tags`
--

LOCK TABLES `journal_tags` WRITE;
/*!40000 ALTER TABLE `journal_tags` DISABLE KEYS */;
/*!40000 ALTER TABLE `journal_tags` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `journals`
--

DROP TABLE IF EXISTS `journals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `journals` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `title` varchar(180) DEFAULT NULL,
  `content` mediumtext NOT NULL,
  `entry_date` date NOT NULL,
  `mood_score` tinyint(3) unsigned DEFAULT NULL,
  `is_private` tinyint(1) NOT NULL DEFAULT 1,
  `is_favorite` tinyint(1) NOT NULL DEFAULT 0,
  `analysis_status` enum('not_requested','pending','completed','failed') NOT NULL DEFAULT 'not_requested',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_journals_user_id` (`user_id`),
  KEY `idx_journals_entry_date` (`entry_date`),
  KEY `idx_journals_favorite` (`user_id`,`is_favorite`),
  KEY `idx_journals_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_journals_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `journals`
--

LOCK TABLES `journals` WRITE;
/*!40000 ALTER TABLE `journals` DISABLE KEYS */;
/*!40000 ALTER TABLE `journals` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `levels`
--

DROP TABLE IF EXISTS `levels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `levels` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `icon_name` varchar(100) DEFAULT NULL,
  `minimum_points` int(10) unsigned NOT NULL DEFAULT 0,
  `maximum_points` int(10) unsigned DEFAULT NULL,
  `display_order` smallint(5) unsigned NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_levels_name` (`name`),
  KEY `idx_levels_points` (`minimum_points`,`maximum_points`),
  KEY `idx_levels_active` (`is_active`),
  KEY `idx_levels_display_order` (`display_order`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `levels`
--

LOCK TABLES `levels` WRITE;
/*!40000 ALTER TABLE `levels` DISABLE KEYS */;
INSERT INTO `levels` VALUES (1,'Beginner','The starting level of the MindPulse wellness journey.','level_beginner',0,99,1,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(2,'Balanced','Awarded for building a more balanced wellness routine.','level_balanced',100,249,2,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(3,'Focused','Awarded for consistent focus and healthy habit development.','level_focused',250,499,3,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(4,'Resilient','Awarded for strong recovery consistency and wellness progress.','level_resilient',500,999,4,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(5,'MindPulse Master','The highest level for long-term wellness consistency.','level_master',1000,NULL,5,1,'2026-07-11 11:05:13','2026-07-11 11:05:13');
/*!40000 ALTER TABLE `levels` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `login_attempts`
--

DROP TABLE IF EXISTS `login_attempts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `login_attempts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(191) NOT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(500) DEFAULT NULL,
  `was_successful` tinyint(1) NOT NULL DEFAULT 0,
  `failure_reason` varchar(150) DEFAULT NULL,
  `attempted_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_login_attempts_email` (`email`),
  KEY `idx_login_attempts_ip` (`ip_address`),
  KEY `idx_login_attempts_time` (`attempted_at`),
  KEY `idx_login_attempts_success` (`was_successful`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `login_attempts`
--

LOCK TABLES `login_attempts` WRITE;
/*!40000 ALTER TABLE `login_attempts` DISABLE KEYS */;
/*!40000 ALTER TABLE `login_attempts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notification_logs`
--

DROP TABLE IF EXISTS `notification_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notification_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `notification_id` bigint(20) unsigned NOT NULL,
  `device_token_id` bigint(20) unsigned DEFAULT NULL,
  `delivery_status` enum('queued','sent','delivered','failed') NOT NULL DEFAULT 'queued',
  `provider_message_id` varchar(255) DEFAULT NULL,
  `attempt_number` tinyint(3) unsigned NOT NULL DEFAULT 1,
  `error_message` varchar(1000) DEFAULT NULL,
  `attempted_at` datetime NOT NULL DEFAULT current_timestamp(),
  `delivered_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_notification_logs_notification_id` (`notification_id`),
  KEY `idx_notification_logs_device_token_id` (`device_token_id`),
  KEY `idx_notification_logs_status` (`delivery_status`),
  KEY `idx_notification_logs_attempted_at` (`attempted_at`),
  CONSTRAINT `fk_notification_logs_device_token` FOREIGN KEY (`device_token_id`) REFERENCES `device_tokens` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_notification_logs_notification` FOREIGN KEY (`notification_id`) REFERENCES `notifications` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notification_logs`
--

LOCK TABLES `notification_logs` WRITE;
/*!40000 ALTER TABLE `notification_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `notification_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notification_preferences`
--

DROP TABLE IF EXISTS `notification_preferences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notification_preferences` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `notifications_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `checkin_reminders` tinyint(1) NOT NULL DEFAULT 1,
  `habit_reminders` tinyint(1) NOT NULL DEFAULT 1,
  `sleep_reminders` tinyint(1) NOT NULL DEFAULT 1,
  `recovery_reminders` tinyint(1) NOT NULL DEFAULT 1,
  `wellness_scan_reminders` tinyint(1) NOT NULL DEFAULT 1,
  `report_notifications` tinyint(1) NOT NULL DEFAULT 1,
  `achievement_notifications` tinyint(1) NOT NULL DEFAULT 1,
  `inactivity_reminders` tinyint(1) NOT NULL DEFAULT 1,
  `announcement_notifications` tinyint(1) NOT NULL DEFAULT 1,
  `quiet_hours_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `quiet_hours_start` time DEFAULT NULL,
  `quiet_hours_end` time DEFAULT NULL,
  `timezone` varchar(60) NOT NULL DEFAULT 'Asia/Dhaka',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_notification_preferences_user_id` (`user_id`),
  CONSTRAINT `fk_notification_preferences_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notification_preferences`
--

LOCK TABLES `notification_preferences` WRITE;
/*!40000 ALTER TABLE `notification_preferences` DISABLE KEYS */;
/*!40000 ALTER TABLE `notification_preferences` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notification_templates`
--

DROP TABLE IF EXISTS `notification_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notification_templates` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `template_code` varchar(100) NOT NULL,
  `notification_type` enum('checkin_reminder','habit_reminder','sleep_reminder','recovery_reminder','wellness_scan_reminder','report_ready','achievement','inactivity','announcement','system') NOT NULL,
  `title_template` varchar(200) NOT NULL,
  `body_template` varchar(1000) NOT NULL,
  `available_variables` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`available_variables`)),
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_notification_templates_code` (`template_code`),
  KEY `idx_notification_templates_type` (`notification_type`),
  KEY `idx_notification_templates_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notification_templates`
--

LOCK TABLES `notification_templates` WRITE;
/*!40000 ALTER TABLE `notification_templates` DISABLE KEYS */;
INSERT INTO `notification_templates` VALUES (1,'DAILY_CHECKIN_REMINDER','checkin_reminder','Time for your daily check-in','Take a moment to record your mood, stress, sleep, and energy.','[\"user_name\"]',1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(2,'HABIT_REMINDER','habit_reminder','Habit reminder','Your {{habit_name}} goal is waiting for you.','[\"user_name\",\"habit_name\"]',1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(3,'SLEEP_REMINDER','sleep_reminder','Prepare for healthy sleep','Start your wind-down routine and prepare for a restful night.','[\"user_name\"]',1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(4,'RECOVERY_REMINDER','recovery_reminder','Recovery activity reminder','A short {{activity_name}} session may help you reset.','[\"user_name\",\"activity_name\"]',1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(5,'WELLNESS_SCAN_REMINDER','wellness_scan_reminder','Complete your wellness scan','Review your recent wellness condition with a short assessment.','[\"user_name\"]',1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(6,'WEEKLY_REPORT_READY','report_ready','Your weekly report is ready','View your recent mood, stress, sleep, habit, and recovery trends.','[\"user_name\",\"report_period\"]',1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(7,'ACHIEVEMENT_EARNED','achievement','New achievement unlocked','You earned the {{badge_name}} badge.','[\"user_name\",\"badge_name\"]',1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(8,'INACTIVITY_REMINDER','inactivity','Your wellness journey is waiting','Return to MindPulse AI and complete a short wellness activity.','[\"user_name\",\"inactive_days\"]',1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(9,'GENERAL_ANNOUNCEMENT','announcement','{{announcement_title}}','{{announcement_body}}','[\"announcement_title\",\"announcement_body\"]',1,'2026-07-11 11:05:13','2026-07-11 11:05:13');
/*!40000 ALTER TABLE `notification_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `template_id` bigint(20) unsigned DEFAULT NULL,
  `created_by_admin_id` bigint(20) unsigned DEFAULT NULL,
  `notification_type` enum('checkin_reminder','habit_reminder','sleep_reminder','recovery_reminder','wellness_scan_reminder','report_ready','achievement','inactivity','announcement','system') NOT NULL,
  `title` varchar(200) NOT NULL,
  `body` varchar(1000) NOT NULL,
  `priority_level` enum('low','normal','high') NOT NULL DEFAULT 'normal',
  `data_payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`data_payload`)),
  `status` enum('pending','scheduled','sent','delivered','failed','read','cancelled') NOT NULL DEFAULT 'pending',
  `scheduled_at` datetime DEFAULT NULL,
  `sent_at` datetime DEFAULT NULL,
  `delivered_at` datetime DEFAULT NULL,
  `read_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_notifications_user_id` (`user_id`),
  KEY `idx_notifications_template_id` (`template_id`),
  KEY `idx_notifications_admin_id` (`created_by_admin_id`),
  KEY `idx_notifications_status` (`status`),
  KEY `idx_notifications_type` (`notification_type`),
  KEY `idx_notifications_scheduled_at` (`scheduled_at`),
  KEY `idx_notifications_read_at` (`user_id`,`read_at`),
  CONSTRAINT `fk_notifications_admin` FOREIGN KEY (`created_by_admin_id`) REFERENCES `admin_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_notifications_template` FOREIGN KEY (`template_id`) REFERENCES `notification_templates` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `password_reset_tokens`
--

DROP TABLE IF EXISTS `password_reset_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `password_reset_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `token_hash` char(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_password_reset_token_hash` (`token_hash`),
  KEY `idx_password_reset_user_id` (`user_id`),
  KEY `idx_password_reset_expires_at` (`expires_at`),
  CONSTRAINT `fk_password_reset_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `password_reset_tokens`
--

LOCK TABLES `password_reset_tokens` WRITE;
/*!40000 ALTER TABLE `password_reset_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `password_reset_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `recovery_activities`
--

DROP TABLE IF EXISTS `recovery_activities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recovery_activities` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(150) NOT NULL,
  `slug` varchar(160) NOT NULL,
  `category` enum('breathing','relaxation','meditation','grounding','stretching','sleep','focus','reflection','digital_break','physical_activity') NOT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `instructions` mediumtext NOT NULL,
  `duration_minutes` smallint(5) unsigned NOT NULL DEFAULT 5,
  `difficulty_level` enum('beginner','intermediate') NOT NULL DEFAULT 'beginner',
  `icon_name` varchar(100) DEFAULT NULL,
  `audio_url` varchar(500) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `display_order` smallint(5) unsigned NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_recovery_activities_slug` (`slug`),
  KEY `idx_recovery_activities_category` (`category`),
  KEY `idx_recovery_activities_active` (`is_active`),
  KEY `idx_recovery_activities_order` (`display_order`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `recovery_activities`
--

LOCK TABLES `recovery_activities` WRITE;
/*!40000 ALTER TABLE `recovery_activities` DISABLE KEYS */;
INSERT INTO `recovery_activities` VALUES (1,'Box Breathing','box-breathing','breathing','A structured breathing exercise for calming the body and mind.','Sit comfortably. Inhale for four seconds. Hold for four seconds. Exhale for four seconds. Hold for four seconds. Repeat slowly.',5,'beginner','air',NULL,1,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(2,'Deep Breathing','deep-breathing','breathing','A gentle breathing activity to reduce immediate tension.','Relax your shoulders. Breathe in slowly through your nose. Pause briefly. Exhale gently through your mouth. Continue at a comfortable pace.',5,'beginner','spa',NULL,1,2,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(3,'5-4-3-2-1 Grounding','five-four-three-two-one-grounding','grounding','A grounding activity that redirects attention to the present moment.','Identify five things you can see, four things you can touch, three things you can hear, two things you can smell, and one thing you can taste.',5,'beginner','filter_5',NULL,1,3,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(4,'One-Minute Focus Reset','one-minute-focus-reset','focus','A short reset activity before returning to work or study.','Pause your current task. Place both feet on the floor. Take three slow breaths. Identify the single next action you need to complete.',1,'beginner','center_focus_strong',NULL,1,4,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(5,'Neck and Shoulder Stretch','neck-shoulder-stretch','stretching','A light stretch for reducing physical tension.','Sit or stand comfortably. Slowly roll your shoulders backward. Gently tilt your head from side to side. Stop immediately if you feel pain.',5,'beginner','accessibility_new',NULL,1,5,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(6,'Short Mindfulness Meditation','short-mindfulness-meditation','meditation','A simple mindfulness exercise for observing thoughts without judgment.','Sit comfortably. Focus on your natural breathing. Notice thoughts as they arise, then gently return attention to your breath.',10,'beginner','self_improvement',NULL,1,6,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(7,'Sleep Wind-Down Routine','sleep-wind-down-routine','sleep','A short preparation routine before bedtime.','Reduce screen brightness. Put away work materials. Complete a gentle stretch. Take several slow breaths and prepare the room for sleep.',15,'beginner','bedtime',NULL,1,7,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(8,'Gratitude Reflection','gratitude-reflection','reflection','A positive reflection exercise focused on meaningful moments.','Write down three things you appreciate today. They can be small events, people, experiences, or personal achievements.',5,'beginner','favorite',NULL,1,8,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(9,'Digital Break','digital-break','digital_break','A short break from digital devices and notifications.','Place your phone away from reach. Step away from the screen. Look outside, stretch, walk, or sit quietly until the activity ends.',10,'beginner','phonelink_off',NULL,1,9,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(10,'Short Recovery Walk','short-recovery-walk','physical_activity','A light walking activity to refresh the body and mind.','Walk at a comfortable pace in a safe area. Pay attention to your surroundings and breathing. Do not push beyond your physical comfort.',10,'beginner','directions_walk',NULL,1,10,'2026-07-11 11:05:13','2026-07-11 11:05:13');
/*!40000 ALTER TABLE `recovery_activities` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `recovery_activity_logs`
--

DROP TABLE IF EXISTS `recovery_activity_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recovery_activity_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `recovery_activity_id` bigint(20) unsigned NOT NULL,
  `status` enum('started','completed','cancelled') NOT NULL DEFAULT 'started',
  `started_at` datetime NOT NULL DEFAULT current_timestamp(),
  `completed_at` datetime DEFAULT NULL,
  `duration_seconds` int(10) unsigned DEFAULT NULL,
  `rating` tinyint(3) unsigned DEFAULT NULL,
  `note` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_recovery_logs_user_id` (`user_id`),
  KEY `idx_recovery_logs_activity_id` (`recovery_activity_id`),
  KEY `idx_recovery_logs_status` (`status`),
  KEY `idx_recovery_logs_started_at` (`started_at`),
  CONSTRAINT `fk_recovery_logs_activity` FOREIGN KEY (`recovery_activity_id`) REFERENCES `recovery_activities` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_recovery_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `recovery_activity_logs`
--

LOCK TABLES `recovery_activity_logs` WRITE;
/*!40000 ALTER TABLE `recovery_activity_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `recovery_activity_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `recovery_plan_tasks`
--

DROP TABLE IF EXISTS `recovery_plan_tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recovery_plan_tasks` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `recovery_plan_id` bigint(20) unsigned NOT NULL,
  `recovery_activity_id` bigint(20) unsigned DEFAULT NULL,
  `title` varchar(180) NOT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `task_type` enum('sleep','hydration','habit','recovery_activity','journal','physical_activity','custom') NOT NULL,
  `target_value` decimal(8,2) DEFAULT NULL,
  `target_unit` varchar(50) DEFAULT NULL,
  `scheduled_date` date NOT NULL,
  `scheduled_time` time DEFAULT NULL,
  `status` enum('pending','completed','skipped','rescheduled') NOT NULL DEFAULT 'pending',
  `completed_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_recovery_tasks_plan_id` (`recovery_plan_id`),
  KEY `idx_recovery_tasks_activity_id` (`recovery_activity_id`),
  KEY `idx_recovery_tasks_date` (`scheduled_date`),
  KEY `idx_recovery_tasks_status` (`status`),
  CONSTRAINT `fk_recovery_tasks_activity` FOREIGN KEY (`recovery_activity_id`) REFERENCES `recovery_activities` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_recovery_tasks_plan` FOREIGN KEY (`recovery_plan_id`) REFERENCES `recovery_plans` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `recovery_plan_tasks`
--

LOCK TABLES `recovery_plan_tasks` WRITE;
/*!40000 ALTER TABLE `recovery_plan_tasks` DISABLE KEYS */;
/*!40000 ALTER TABLE `recovery_plan_tasks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `recovery_plans`
--

DROP TABLE IF EXISTS `recovery_plans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recovery_plans` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `title` varchar(180) NOT NULL,
  `description` text DEFAULT NULL,
  `overall_goal` varchar(500) DEFAULT NULL,
  `generated_by` enum('rule_based','ai','manual') NOT NULL DEFAULT 'rule_based',
  `status` enum('active','completed','paused','cancelled') NOT NULL DEFAULT 'active',
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL,
  `review_date` date DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_recovery_plans_user_id` (`user_id`),
  KEY `idx_recovery_plans_status` (`user_id`,`status`),
  KEY `idx_recovery_plans_start_date` (`start_date`),
  CONSTRAINT `fk_recovery_plans_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `recovery_plans`
--

LOCK TABLES `recovery_plans` WRITE;
/*!40000 ALTER TABLE `recovery_plans` DISABLE KEYS */;
/*!40000 ALTER TABLE `recovery_plans` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `recovery_progress`
--

DROP TABLE IF EXISTS `recovery_progress`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recovery_progress` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `recovery_plan_id` bigint(20) unsigned DEFAULT NULL,
  `progress_date` date NOT NULL,
  `mood_score` decimal(5,2) DEFAULT NULL,
  `stress_score` decimal(5,2) DEFAULT NULL,
  `sleep_hours` decimal(4,2) DEFAULT NULL,
  `energy_level` decimal(5,2) DEFAULT NULL,
  `habit_completion_percent` decimal(5,2) DEFAULT NULL,
  `activity_completion_percent` decimal(5,2) DEFAULT NULL,
  `burnout_score` decimal(5,2) DEFAULT NULL,
  `recovery_score` decimal(5,2) NOT NULL,
  `note` varchar(1000) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_recovery_progress_user_date` (`user_id`,`progress_date`),
  KEY `idx_recovery_progress_user_id` (`user_id`),
  KEY `idx_recovery_progress_plan_id` (`recovery_plan_id`),
  KEY `idx_recovery_progress_date` (`progress_date`),
  KEY `idx_recovery_progress_score` (`recovery_score`),
  CONSTRAINT `fk_recovery_progress_plan` FOREIGN KEY (`recovery_plan_id`) REFERENCES `recovery_plans` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_recovery_progress_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `recovery_progress`
--

LOCK TABLES `recovery_progress` WRITE;
/*!40000 ALTER TABLE `recovery_progress` DISABLE KEYS */;
/*!40000 ALTER TABLE `recovery_progress` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `refresh_tokens`
--

DROP TABLE IF EXISTS `refresh_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `refresh_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `token_hash` char(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `replaced_by_token_hash` char(64) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_refresh_tokens_token_hash` (`token_hash`),
  KEY `idx_refresh_tokens_user_id` (`user_id`),
  KEY `idx_refresh_tokens_expires_at` (`expires_at`),
  KEY `idx_refresh_tokens_revoked_at` (`revoked_at`),
  CONSTRAINT `fk_refresh_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `refresh_tokens`
--

LOCK TABLES `refresh_tokens` WRITE;
/*!40000 ALTER TABLE `refresh_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `refresh_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `report_files`
--

DROP TABLE IF EXISTS `report_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `report_files` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `report_id` bigint(20) unsigned NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_path` varchar(1000) NOT NULL,
  `mime_type` varchar(100) NOT NULL DEFAULT 'application/pdf',
  `file_size_bytes` bigint(20) unsigned DEFAULT NULL,
  `storage_type` enum('local','cloud') NOT NULL DEFAULT 'local',
  `checksum_sha256` char(64) DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_report_files_report_id` (`report_id`),
  KEY `idx_report_files_storage_type` (`storage_type`),
  KEY `idx_report_files_expires_at` (`expires_at`),
  CONSTRAINT `fk_report_files_report` FOREIGN KEY (`report_id`) REFERENCES `reports` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `report_files`
--

LOCK TABLES `report_files` WRITE;
/*!40000 ALTER TABLE `report_files` DISABLE KEYS */;
/*!40000 ALTER TABLE `report_files` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reports`
--

DROP TABLE IF EXISTS `reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `reports` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `report_type` enum('weekly','monthly','burnout','habit','sleep','recovery','custom') NOT NULL,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `status` enum('pending','generating','completed','failed') NOT NULL DEFAULT 'pending',
  `summary` mediumtext DEFAULT NULL,
  `metrics` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`metrics`)),
  `recommendations` mediumtext DEFAULT NULL,
  `generated_by` enum('system','ai','manual') NOT NULL DEFAULT 'system',
  `algorithm_version` varchar(50) DEFAULT NULL,
  `generated_at` datetime DEFAULT NULL,
  `failure_reason` varchar(1000) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_reports_user_id` (`user_id`),
  KEY `idx_reports_type` (`report_type`),
  KEY `idx_reports_status` (`status`),
  KEY `idx_reports_period` (`period_start`,`period_end`),
  KEY `idx_reports_created_at` (`created_at`),
  CONSTRAINT `fk_reports_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reports`
--

LOCK TABLES `reports` WRITE;
/*!40000 ALTER TABLE `reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `support_resources`
--

DROP TABLE IF EXISTS `support_resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `support_resources` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `country_code` char(2) NOT NULL,
  `region_name` varchar(120) DEFAULT NULL,
  `resource_type` enum('emergency_service','crisis_hotline','professional_support','mental_health_service','trusted_contact_guidance','other') NOT NULL,
  `name` varchar(200) NOT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `phone_number` varchar(50) DEFAULT NULL,
  `website_url` varchar(1000) DEFAULT NULL,
  `availability_text` varchar(255) DEFAULT NULL,
  `supported_languages` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`supported_languages`)),
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `display_order` smallint(5) unsigned NOT NULL DEFAULT 0,
  `updated_by_admin_id` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_support_resources_country` (`country_code`),
  KEY `idx_support_resources_region` (`region_name`),
  KEY `idx_support_resources_type` (`resource_type`),
  KEY `idx_support_resources_active` (`is_active`),
  KEY `idx_support_resources_order` (`display_order`),
  KEY `fk_support_resources_admin` (`updated_by_admin_id`),
  CONSTRAINT `fk_support_resources_admin` FOREIGN KEY (`updated_by_admin_id`) REFERENCES `admin_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `support_resources`
--

LOCK TABLES `support_resources` WRITE;
/*!40000 ALTER TABLE `support_resources` DISABLE KEYS */;
/*!40000 ALTER TABLE `support_resources` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `system_logs`
--

DROP TABLE IF EXISTS `system_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `system_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `log_level` enum('debug','info','warning','error','critical') NOT NULL DEFAULT 'info',
  `service_name` enum('backend','ai_service','database','notification','admin_dashboard','mobile_app','other') NOT NULL,
  `event_code` varchar(100) DEFAULT NULL,
  `message` varchar(2000) NOT NULL,
  `context_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`context_data`)),
  `stack_trace` mediumtext DEFAULT NULL,
  `request_id` varchar(100) DEFAULT NULL,
  `occurred_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_system_logs_level` (`log_level`),
  KEY `idx_system_logs_service` (`service_name`),
  KEY `idx_system_logs_event_code` (`event_code`),
  KEY `idx_system_logs_request_id` (`request_id`),
  KEY `idx_system_logs_occurred_at` (`occurred_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `system_logs`
--

LOCK TABLES `system_logs` WRITE;
/*!40000 ALTER TABLE `system_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `system_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_badges`
--

DROP TABLE IF EXISTS `user_badges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_badges` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `badge_id` bigint(20) unsigned NOT NULL,
  `earned_at` datetime NOT NULL DEFAULT current_timestamp(),
  `points_awarded` int(10) unsigned NOT NULL DEFAULT 0,
  `criteria_snapshot` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`criteria_snapshot`)),
  `source_reference_type` varchar(80) DEFAULT NULL,
  `source_reference_id` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_badges_user_badge` (`user_id`,`badge_id`),
  KEY `idx_user_badges_user_id` (`user_id`),
  KEY `idx_user_badges_badge_id` (`badge_id`),
  KEY `idx_user_badges_earned_at` (`earned_at`),
  CONSTRAINT `fk_user_badges_badge` FOREIGN KEY (`badge_id`) REFERENCES `badges` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_user_badges_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_badges`
--

LOCK TABLES `user_badges` WRITE;
/*!40000 ALTER TABLE `user_badges` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_badges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_consents`
--

DROP TABLE IF EXISTS `user_consents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_consents` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `consent_type` enum('terms','privacy','wellness_data','ai_analysis','journal_analysis','analytics','notifications') NOT NULL,
  `is_granted` tinyint(1) NOT NULL DEFAULT 0,
  `policy_version` varchar(30) DEFAULT NULL,
  `granted_at` datetime DEFAULT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_consent_type` (`user_id`,`consent_type`),
  KEY `idx_user_consents_user_id` (`user_id`),
  CONSTRAINT `fk_user_consents_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_consents`
--

LOCK TABLES `user_consents` WRITE;
/*!40000 ALTER TABLE `user_consents` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_consents` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_data_requests`
--

DROP TABLE IF EXISTS `user_data_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_data_requests` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `requested_email` varchar(191) NOT NULL,
  `request_type` enum('data_export','account_deletion') NOT NULL,
  `status` enum('pending','processing','completed','rejected','cancelled') NOT NULL DEFAULT 'pending',
  `reason` varchar(1000) DEFAULT NULL,
  `export_file_path` varchar(1000) DEFAULT NULL,
  `export_expires_at` datetime DEFAULT NULL,
  `processed_by_admin_id` bigint(20) unsigned DEFAULT NULL,
  `processed_at` datetime DEFAULT NULL,
  `rejection_reason` varchar(1000) DEFAULT NULL,
  `requested_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_data_requests_user_id` (`user_id`),
  KEY `idx_data_requests_email` (`requested_email`),
  KEY `idx_data_requests_type` (`request_type`),
  KEY `idx_data_requests_status` (`status`),
  KEY `idx_data_requests_requested_at` (`requested_at`),
  KEY `idx_data_requests_admin_id` (`processed_by_admin_id`),
  CONSTRAINT `fk_data_requests_admin` FOREIGN KEY (`processed_by_admin_id`) REFERENCES `admin_users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_data_requests_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_data_requests`
--

LOCK TABLES `user_data_requests` WRITE;
/*!40000 ALTER TABLE `user_data_requests` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_data_requests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_levels`
--

DROP TABLE IF EXISTS `user_levels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_levels` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `level_id` bigint(20) unsigned NOT NULL,
  `total_points` int(10) unsigned NOT NULL DEFAULT 0,
  `achieved_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_levels_user_id` (`user_id`),
  KEY `idx_user_levels_level_id` (`level_id`),
  KEY `idx_user_levels_points` (`total_points`),
  CONSTRAINT `fk_user_levels_level` FOREIGN KEY (`level_id`) REFERENCES `levels` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_user_levels_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_levels`
--

LOCK TABLES `user_levels` WRITE;
/*!40000 ALTER TABLE `user_levels` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_levels` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_profiles`
--

DROP TABLE IF EXISTS `user_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_profiles` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `full_name` varchar(120) NOT NULL,
  `profile_photo_url` varchar(500) DEFAULT NULL,
  `age_range` varchar(30) DEFAULT NULL,
  `gender` enum('male','female','other','prefer_not_to_say') DEFAULT NULL,
  `occupation` varchar(120) DEFAULT NULL,
  `user_type` enum('student','employee','self_employed','other') DEFAULT NULL,
  `wellness_goal` varchar(150) DEFAULT NULL,
  `preferred_language` varchar(10) NOT NULL DEFAULT 'en',
  `timezone` varchar(60) NOT NULL DEFAULT 'Asia/Dhaka',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_profiles_user_id` (`user_id`),
  CONSTRAINT `fk_user_profiles_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_profiles`
--

LOCK TABLES `user_profiles` WRITE;
/*!40000 ALTER TABLE `user_profiles` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_profiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_settings`
--

DROP TABLE IF EXISTS `user_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_settings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `theme_mode` enum('system','light','dark') NOT NULL DEFAULT 'system',
  `language_code` varchar(10) NOT NULL DEFAULT 'en',
  `time_format` enum('12_hour','24_hour') NOT NULL DEFAULT '12_hour',
  `ai_analysis_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `journal_analysis_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `analytics_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_user_settings_user_id` (`user_id`),
  CONSTRAINT `fk_user_settings_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_settings`
--

LOCK TABLES `user_settings` WRITE;
/*!40000 ALTER TABLE `user_settings` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(191) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `account_status` enum('active','suspended','inactive') NOT NULL DEFAULT 'active',
  `onboarding_completed` tinyint(1) NOT NULL DEFAULT 0,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `last_login_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_email` (`email`),
  KEY `idx_users_account_status` (`account_status`),
  KEY `idx_users_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wellness_questions`
--

DROP TABLE IF EXISTS `wellness_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wellness_questions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `question_code` varchar(50) NOT NULL,
  `question_text` varchar(500) NOT NULL,
  `category` varchar(80) NOT NULL,
  `response_scale` enum('1_to_5','1_to_10','yes_no') NOT NULL DEFAULT '1_to_5',
  `display_order` smallint(5) unsigned NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_wellness_questions_code` (`question_code`),
  KEY `idx_wellness_questions_category` (`category`),
  KEY `idx_wellness_questions_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wellness_questions`
--

LOCK TABLES `wellness_questions` WRITE;
/*!40000 ALTER TABLE `wellness_questions` DISABLE KEYS */;
INSERT INTO `wellness_questions` VALUES (1,'EMOTIONAL_EXHAUSTION','How emotionally exhausted have you felt recently?','emotional_exhaustion','1_to_5',1,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(2,'WORK_STUDY_PRESSURE','How much pressure are you experiencing from work or study?','work_study_pressure','1_to_5',2,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(3,'SLEEP_DISTURBANCE','How often has poor sleep affected your daily routine?','sleep','1_to_5',3,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(4,'LOW_MOTIVATION','How difficult has it been to stay motivated?','motivation','1_to_5',4,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(5,'CONCENTRATION_DIFFICULTY','How difficult has it been to concentrate?','concentration','1_to_5',5,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(6,'IRRITABILITY','How often have you felt unusually irritated or frustrated?','irritability','1_to_5',6,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(7,'SOCIAL_WITHDRAWAL','How often have you avoided social interaction because of tiredness or stress?','social_wellness','1_to_5',7,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(8,'PHYSICAL_TIREDNESS','How physically tired have you felt during normal daily activities?','physical_wellness','1_to_5',8,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(9,'WORK_LIFE_BALANCE','How difficult has it been to maintain a healthy work-life balance?','work_life_balance','1_to_5',9,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(10,'RECOVERY_ABILITY','How difficult has it been to recover after stressful situations?','recovery','1_to_5',10,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(11,'FEELING_OVERWHELMED','How often have you felt overwhelmed by your responsibilities?','stress','1_to_5',11,1,'2026-07-11 11:05:13','2026-07-11 11:05:13'),(12,'LOSS_OF_INTEREST','How often have you lost interest in activities you normally enjoy?','emotional_wellness','1_to_5',12,1,'2026-07-11 11:05:13','2026-07-11 11:05:13');
/*!40000 ALTER TABLE `wellness_questions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wellness_scan_answers`
--

DROP TABLE IF EXISTS `wellness_scan_answers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wellness_scan_answers` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `wellness_scan_id` bigint(20) unsigned NOT NULL,
  `question_id` bigint(20) unsigned NOT NULL,
  `response_value` tinyint(3) unsigned DEFAULT NULL,
  `response_text` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_scan_question` (`wellness_scan_id`,`question_id`),
  KEY `idx_scan_answers_scan_id` (`wellness_scan_id`),
  KEY `idx_scan_answers_question_id` (`question_id`),
  CONSTRAINT `fk_scan_answers_question` FOREIGN KEY (`question_id`) REFERENCES `wellness_questions` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_scan_answers_scan` FOREIGN KEY (`wellness_scan_id`) REFERENCES `wellness_scans` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wellness_scan_answers`
--

LOCK TABLES `wellness_scan_answers` WRITE;
/*!40000 ALTER TABLE `wellness_scan_answers` DISABLE KEYS */;
/*!40000 ALTER TABLE `wellness_scan_answers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wellness_scans`
--

DROP TABLE IF EXISTS `wellness_scans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `wellness_scans` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `total_score` decimal(5,2) NOT NULL,
  `risk_level` enum('low','mild','moderate','elevated') NOT NULL,
  `main_factors` text DEFAULT NULL,
  `summary` text DEFAULT NULL,
  `recommendation` text DEFAULT NULL,
  `completed_at` datetime NOT NULL DEFAULT current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_wellness_scans_user_id` (`user_id`),
  KEY `idx_wellness_scans_risk_level` (`risk_level`),
  KEY `idx_wellness_scans_completed_at` (`completed_at`),
  CONSTRAINT `fk_wellness_scans_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wellness_scans`
--

LOCK TABLES `wellness_scans` WRITE;
/*!40000 ALTER TABLE `wellness_scans` DISABLE KEYS */;
/*!40000 ALTER TABLE `wellness_scans` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping events for database 'mindpulse_ai'
--

--
-- Dumping routines for database 'mindpulse_ai'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-11 17:06:21
