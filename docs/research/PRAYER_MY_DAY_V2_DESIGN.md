# Prayer Reminder + My Day V2

Target baseline: `efb09e2`

## User-approved prayer message

The prayer notification body and Bengali voice use only:

> নামাজের সময় হয়ে যাচ্ছে। আপনারা নামাজের প্রস্তুতি নিন।

The prayer reminder does not claim a mosque, congregation, or congregation
start time.

## Default reminder rules

- Dhuhr reminder: 13:05
- Friday Jummah reminder: 12:35
- Fajr, Asr, Maghrib and Isha: 10 minutes before the calculated online prayer
  time unless the user chooses a different reminder time
- Horizon: 30 days

Calculated online prayer times and reminder times are stored and displayed as
different values.

## Android reliability

- Notification permission is requested on Android 13 and later.
- Exact-alarm access is checked before exact scheduling.
- When exact-alarm access is missing, the native scheduler degrades to an
  inexact idle-capable alarm until the user grants access.
- Scheduled alarms are persisted.
- A boot/package-replace receiver reschedules the current schema.
- Old stored prayer schedules are invalidated by a native schedule version so
  outdated wording and times are not restored after an app update.

Android references:

- https://developer.android.com/develop/background-work/services/alarms
- https://developer.android.com/about/versions/14/changes/schedule-exact-alarms
- https://developer.android.com/develop/ui/compose/notifications/notification-permission

## My Day V2

The local schedule keeps the existing SharedPreferences key and migrates old
tasks. Each task now stores:

- calendar date
- start time and duration
- category and source
- pending, completed, or skipped status
- notes and timestamps

The timeline supports add, edit/reschedule, complete, skip, restore, delete,
seven-day navigation, and overlap warnings. AI Guide sessions are imported
with source `ai_guide` and assigned to the next matching weekday.

## Honest limitations

- My Day remains local to the device in this batch; account/backend sync is not
  claimed.
- General My Day task alarms are not implemented in this batch. The old
  non-functional alarm toggle is therefore not shown.
- Online prayer calculations depend on location/network availability. A
  fallback location is shown transparently when needed.
