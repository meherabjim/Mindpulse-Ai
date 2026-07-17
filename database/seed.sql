USE mindpulse_ai;

START TRANSACTION;

-- =====================================================
-- 1. LEVELS
-- =====================================================
INSERT INTO levels (
    name,
    description,
    icon_name,
    minimum_points,
    maximum_points,
    display_order,
    is_active
)
VALUES
(
    'Beginner',
    'The starting level of the MindPulse wellness journey.',
    'level_beginner',
    0,
    99,
    1,
    TRUE
),
(
    'Balanced',
    'Awarded for building a more balanced wellness routine.',
    'level_balanced',
    100,
    249,
    2,
    TRUE
),
(
    'Focused',
    'Awarded for consistent focus and healthy habit development.',
    'level_focused',
    250,
    499,
    3,
    TRUE
),
(
    'Resilient',
    'Awarded for strong recovery consistency and wellness progress.',
    'level_resilient',
    500,
    999,
    4,
    TRUE
),
(
    'MindPulse Master',
    'The highest level for long-term wellness consistency.',
    'level_master',
    1000,
    NULL,
    5,
    TRUE
)
ON DUPLICATE KEY UPDATE
    description = VALUES(description),
    icon_name = VALUES(icon_name),
    minimum_points = VALUES(minimum_points),
    maximum_points = VALUES(maximum_points),
    display_order = VALUES(display_order),
    is_active = VALUES(is_active);


-- =====================================================
-- 2. BADGES
-- =====================================================
INSERT INTO badges (
    badge_code,
    name,
    description,
    category,
    criteria_type,
    criteria_value,
    points_reward,
    icon_name,
    is_active,
    display_order
)
VALUES
(
    'FIRST_CHECKIN',
    'First Check-in',
    'Complete the first daily wellness check-in.',
    'checkin',
    'total_checkins',
    1,
    10,
    'badge_first_checkin',
    TRUE,
    1
),
(
    'CHECKIN_7_DAY',
    '7-Day Check-in',
    'Complete daily check-ins for seven consecutive days.',
    'checkin',
    'checkin_streak',
    7,
    30,
    'badge_checkin_7',
    TRUE,
    2
),
(
    'CHECKIN_30_DAY',
    '30-Day Check-in',
    'Complete daily check-ins for thirty consecutive days.',
    'consistency',
    'checkin_streak',
    30,
    100,
    'badge_checkin_30',
    TRUE,
    3
),
(
    'WATER_HERO',
    'Water Hero',
    'Achieve the daily hydration target seven times.',
    'hydration',
    'hydration_target_days',
    7,
    25,
    'badge_water_hero',
    TRUE,
    4
),
(
    'SLEEP_CHAMPION',
    'Sleep Champion',
    'Meet the healthy sleep target seven times.',
    'sleep',
    'sleep_target_days',
    7,
    25,
    'badge_sleep_champion',
    TRUE,
    5
),
(
    'CALM_MIND',
    'Calm Mind',
    'Complete ten breathing, meditation, or grounding activities.',
    'recovery',
    'calm_activity_count',
    10,
    40,
    'badge_calm_mind',
    TRUE,
    6
),
(
    'JOURNAL_STREAK',
    'Journal Streak',
    'Write journal entries for seven consecutive days.',
    'journal',
    'journal_streak',
    7,
    35,
    'badge_journal_streak',
    TRUE,
    7
),
(
    'ACTIVE_WALKER',
    'Active Walker',
    'Complete ten walking or physical activity habits.',
    'activity',
    'walking_completion_count',
    10,
    30,
    'badge_active_walker',
    TRUE,
    8
),
(
    'HABIT_BUILDER',
    'Habit Builder',
    'Complete twenty-five habit logs.',
    'habit',
    'habit_completion_count',
    25,
    50,
    'badge_habit_builder',
    TRUE,
    9
),
(
    'RECOVERY_MILESTONE',
    'Recovery Milestone',
    'Reach seventy-five percent recovery progress.',
    'recovery',
    'recovery_score',
    75,
    60,
    'badge_recovery_milestone',
    TRUE,
    10
),
(
    'WELLNESS_EXPLORER',
    'Wellness Explorer',
    'Complete five detailed wellness scans.',
    'wellness',
    'wellness_scan_count',
    5,
    30,
    'badge_wellness_explorer',
    TRUE,
    11
)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    description = VALUES(description),
    category = VALUES(category),
    criteria_type = VALUES(criteria_type),
    criteria_value = VALUES(criteria_value),
    points_reward = VALUES(points_reward),
    icon_name = VALUES(icon_name),
    is_active = VALUES(is_active),
    display_order = VALUES(display_order);


-- =====================================================
-- 3. WELLNESS QUESTIONS
-- =====================================================
INSERT INTO wellness_questions (
    question_code,
    question_text,
    category,
    response_scale,
    display_order,
    is_active
)
VALUES
(
    'EMOTIONAL_EXHAUSTION',
    'How emotionally exhausted have you felt recently?',
    'emotional_exhaustion',
    '1_to_5',
    1,
    TRUE
),
(
    'WORK_STUDY_PRESSURE',
    'How much pressure are you experiencing from work or study?',
    'work_study_pressure',
    '1_to_5',
    2,
    TRUE
),
(
    'SLEEP_DISTURBANCE',
    'How often has poor sleep affected your daily routine?',
    'sleep',
    '1_to_5',
    3,
    TRUE
),
(
    'LOW_MOTIVATION',
    'How difficult has it been to stay motivated?',
    'motivation',
    '1_to_5',
    4,
    TRUE
),
(
    'CONCENTRATION_DIFFICULTY',
    'How difficult has it been to concentrate?',
    'concentration',
    '1_to_5',
    5,
    TRUE
),
(
    'IRRITABILITY',
    'How often have you felt unusually irritated or frustrated?',
    'irritability',
    '1_to_5',
    6,
    TRUE
),
(
    'SOCIAL_WITHDRAWAL',
    'How often have you avoided social interaction because of tiredness or stress?',
    'social_wellness',
    '1_to_5',
    7,
    TRUE
),
(
    'PHYSICAL_TIREDNESS',
    'How physically tired have you felt during normal daily activities?',
    'physical_wellness',
    '1_to_5',
    8,
    TRUE
),
(
    'WORK_LIFE_BALANCE',
    'How difficult has it been to maintain a healthy work-life balance?',
    'work_life_balance',
    '1_to_5',
    9,
    TRUE
),
(
    'RECOVERY_ABILITY',
    'How difficult has it been to recover after stressful situations?',
    'recovery',
    '1_to_5',
    10,
    TRUE
),
(
    'FEELING_OVERWHELMED',
    'How often have you felt overwhelmed by your responsibilities?',
    'stress',
    '1_to_5',
    11,
    TRUE
),
(
    'LOSS_OF_INTEREST',
    'How often have you lost interest in activities you normally enjoy?',
    'emotional_wellness',
    '1_to_5',
    12,
    TRUE
)
ON DUPLICATE KEY UPDATE
    question_text = VALUES(question_text),
    category = VALUES(category),
    response_scale = VALUES(response_scale),
    display_order = VALUES(display_order),
    is_active = VALUES(is_active);


-- =====================================================
-- 4. HABIT TEMPLATES
-- =====================================================
INSERT INTO habit_templates (
    name,
    category,
    description,
    icon_name,
    default_target_value,
    default_unit,
    is_active,
    display_order
)
VALUES
(
    'Drink Water',
    'hydration',
    'Maintain regular water intake throughout the day.',
    'water_drop',
    8,
    'glasses',
    TRUE,
    1
),
(
    'Healthy Sleep',
    'sleep',
    'Maintain a consistent and healthy sleep routine.',
    'bedtime',
    8,
    'hours',
    TRUE,
    2
),
(
    'Daily Walk',
    'walking',
    'Take a short walk to support physical and emotional wellness.',
    'directions_walk',
    20,
    'minutes',
    TRUE,
    3
),
(
    'Meditation',
    'meditation',
    'Practice a short mindfulness or meditation activity.',
    'self_improvement',
    10,
    'minutes',
    TRUE,
    4
),
(
    'Exercise',
    'exercise',
    'Complete a light or moderate physical exercise session.',
    'fitness_center',
    20,
    'minutes',
    TRUE,
    5
),
(
    'Write Journal',
    'journaling',
    'Write a short reflection about the day.',
    'menu_book',
    1,
    'entry',
    TRUE,
    6
),
(
    'Screen Break',
    'digital_wellness',
    'Take regular breaks from phones and computer screens.',
    'phonelink_off',
    3,
    'breaks',
    TRUE,
    7
),
(
    'Read a Book',
    'reading',
    'Spend a short period reading something meaningful.',
    'auto_stories',
    15,
    'minutes',
    TRUE,
    8
),
(
    'Healthy Meal',
    'nutrition',
    'Complete the daily healthy meal goal.',
    'restaurant',
    2,
    'meals',
    TRUE,
    9
),
(
    'Breathing Exercise',
    'breathing',
    'Complete a short calming breathing exercise.',
    'air',
    5,
    'minutes',
    TRUE,
    10
)
ON DUPLICATE KEY UPDATE
    category = VALUES(category),
    description = VALUES(description),
    icon_name = VALUES(icon_name),
    default_target_value = VALUES(default_target_value),
    default_unit = VALUES(default_unit),
    is_active = VALUES(is_active),
    display_order = VALUES(display_order);


-- =====================================================
-- 5. RECOVERY ACTIVITIES
-- =====================================================
INSERT INTO recovery_activities (
    title,
    slug,
    category,
    description,
    instructions,
    duration_minutes,
    difficulty_level,
    icon_name,
    audio_url,
    is_active,
    display_order
)
VALUES
(
    'Box Breathing',
    'box-breathing',
    'breathing',
    'A structured breathing exercise for calming the body and mind.',
    'Sit comfortably. Inhale for four seconds. Hold for four seconds. Exhale for four seconds. Hold for four seconds. Repeat slowly.',
    5,
    'beginner',
    'air',
    NULL,
    TRUE,
    1
),
(
    'Deep Breathing',
    'deep-breathing',
    'breathing',
    'A gentle breathing activity to reduce immediate tension.',
    'Relax your shoulders. Breathe in slowly through your nose. Pause briefly. Exhale gently through your mouth. Continue at a comfortable pace.',
    5,
    'beginner',
    'spa',
    NULL,
    TRUE,
    2
),
(
    '5-4-3-2-1 Grounding',
    'five-four-three-two-one-grounding',
    'grounding',
    'A grounding activity that redirects attention to the present moment.',
    'Identify five things you can see, four things you can touch, three things you can hear, two things you can smell, and one thing you can taste.',
    5,
    'beginner',
    'filter_5',
    NULL,
    TRUE,
    3
),
(
    'One-Minute Focus Reset',
    'one-minute-focus-reset',
    'focus',
    'A short reset activity before returning to work or study.',
    'Pause your current task. Place both feet on the floor. Take three slow breaths. Identify the single next action you need to complete.',
    1,
    'beginner',
    'center_focus_strong',
    NULL,
    TRUE,
    4
),
(
    'Neck and Shoulder Stretch',
    'neck-shoulder-stretch',
    'stretching',
    'A light stretch for reducing physical tension.',
    'Sit or stand comfortably. Slowly roll your shoulders backward. Gently tilt your head from side to side. Stop immediately if you feel pain.',
    5,
    'beginner',
    'accessibility_new',
    NULL,
    TRUE,
    5
),
(
    'Short Mindfulness Meditation',
    'short-mindfulness-meditation',
    'meditation',
    'A simple mindfulness exercise for observing thoughts without judgment.',
    'Sit comfortably. Focus on your natural breathing. Notice thoughts as they arise, then gently return attention to your breath.',
    10,
    'beginner',
    'self_improvement',
    NULL,
    TRUE,
    6
),
(
    'Sleep Wind-Down Routine',
    'sleep-wind-down-routine',
    'sleep',
    'A short preparation routine before bedtime.',
    'Reduce screen brightness. Put away work materials. Complete a gentle stretch. Take several slow breaths and prepare the room for sleep.',
    15,
    'beginner',
    'bedtime',
    NULL,
    TRUE,
    7
),
(
    'Gratitude Reflection',
    'gratitude-reflection',
    'reflection',
    'A positive reflection exercise focused on meaningful moments.',
    'Write down three things you appreciate today. They can be small events, people, experiences, or personal achievements.',
    5,
    'beginner',
    'favorite',
    NULL,
    TRUE,
    8
),
(
    'Digital Break',
    'digital-break',
    'digital_break',
    'A short break from digital devices and notifications.',
    'Place your phone away from reach. Step away from the screen. Look outside, stretch, walk, or sit quietly until the activity ends.',
    10,
    'beginner',
    'phonelink_off',
    NULL,
    TRUE,
    9
),
(
    'Short Recovery Walk',
    'short-recovery-walk',
    'physical_activity',
    'A light walking activity to refresh the body and mind.',
    'Walk at a comfortable pace in a safe area. Pay attention to your surroundings and breathing. Do not push beyond your physical comfort.',
    10,
    'beginner',
    'directions_walk',
    NULL,
    TRUE,
    10
)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    category = VALUES(category),
    description = VALUES(description),
    instructions = VALUES(instructions),
    duration_minutes = VALUES(duration_minutes),
    difficulty_level = VALUES(difficulty_level),
    icon_name = VALUES(icon_name),
    audio_url = VALUES(audio_url),
    is_active = VALUES(is_active),
    display_order = VALUES(display_order);


-- =====================================================
-- 6. NOTIFICATION TEMPLATES
-- =====================================================
INSERT INTO notification_templates (
    template_code,
    notification_type,
    title_template,
    body_template,
    available_variables,
    is_active
)
VALUES
(
    'DAILY_CHECKIN_REMINDER',
    'checkin_reminder',
    'Time for your daily check-in',
    'Take a moment to record your mood, stress, sleep, and energy.',
    '["user_name"]',
    TRUE
),
(
    'HABIT_REMINDER',
    'habit_reminder',
    'Habit reminder',
    'Your {{habit_name}} goal is waiting for you.',
    '["user_name","habit_name"]',
    TRUE
),
(
    'SLEEP_REMINDER',
    'sleep_reminder',
    'Prepare for healthy sleep',
    'Start your wind-down routine and prepare for a restful night.',
    '["user_name"]',
    TRUE
),
(
    'RECOVERY_REMINDER',
    'recovery_reminder',
    'Recovery activity reminder',
    'A short {{activity_name}} session may help you reset.',
    '["user_name","activity_name"]',
    TRUE
),
(
    'WELLNESS_SCAN_REMINDER',
    'wellness_scan_reminder',
    'Complete your wellness scan',
    'Review your recent wellness condition with a short assessment.',
    '["user_name"]',
    TRUE
),
(
    'WEEKLY_REPORT_READY',
    'report_ready',
    'Your weekly report is ready',
    'View your recent mood, stress, sleep, habit, and recovery trends.',
    '["user_name","report_period"]',
    TRUE
),
(
    'ACHIEVEMENT_EARNED',
    'achievement',
    'New achievement unlocked',
    'You earned the {{badge_name}} badge.',
    '["user_name","badge_name"]',
    TRUE
),
(
    'INACTIVITY_REMINDER',
    'inactivity',
    'Your wellness journey is waiting',
    'Return to MindPulse AI and complete a short wellness activity.',
    '["user_name","inactive_days"]',
    TRUE
),
(
    'GENERAL_ANNOUNCEMENT',
    'announcement',
    '{{announcement_title}}',
    '{{announcement_body}}',
    '["announcement_title","announcement_body"]',
    TRUE
)
ON DUPLICATE KEY UPDATE
    notification_type = VALUES(notification_type),
    title_template = VALUES(title_template),
    body_template = VALUES(body_template),
    available_variables = VALUES(available_variables),
    is_active = VALUES(is_active);


-- =====================================================
-- 7. BASIC APP CONTENT
-- =====================================================
INSERT INTO app_contents (
    content_key,
    content_type,
    title,
    content,
    version,
    language_code,
    is_active,
    published_at,
    updated_by_admin_id
)
VALUES
(
    'wellness_disclaimer',
    'wellness_disclaimer',
    'Wellness Disclaimer',
    'MindPulse AI is a wellness-support application. It does not provide medical diagnosis, professional psychological treatment, emergency response, or medication advice. Users should seek qualified professional support when necessary.',
    '1.0',
    'en',
    TRUE,
    CURRENT_TIMESTAMP,
    NULL
),
(
    'about_mindpulse',
    'about',
    'About MindPulse AI',
    'MindPulse AI helps users record wellness information, understand personal trends, develop healthy habits, and follow supportive recovery activities.',
    '1.0',
    'en',
    TRUE,
    CURRENT_TIMESTAMP,
    NULL
),
(
    'privacy_policy_draft',
    'privacy_policy',
    'Privacy Policy Draft',
    'This is a demonstration privacy policy for the MindPulse AI academic project. A complete production privacy policy must be reviewed before public deployment.',
    '1.0',
    'en',
    FALSE,
    NULL,
    NULL
),
(
    'terms_draft',
    'terms',
    'Terms and Conditions Draft',
    'These demonstration terms are provided for the MindPulse AI academic project. Final legal terms must be reviewed before public deployment.',
    '1.0',
    'en',
    FALSE,
    NULL,
    NULL
)
ON DUPLICATE KEY UPDATE
    content_type = VALUES(content_type),
    title = VALUES(title),
    content = VALUES(content),
    is_active = VALUES(is_active),
    published_at = VALUES(published_at);

COMMIT;
