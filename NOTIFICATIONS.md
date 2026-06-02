# Notifications Write-Up

CBT notifications are optional, user-controlled reminders designed to help people return to the skills and reflections they have already chosen to use. They are not alarms, emergency interventions, clinical monitoring, or a replacement for professional support. Their role is to offer a timely, respectful prompt that brings the user back to mood awareness, thought work, breathing, journaling, planned activities, learning, and end-of-day closure.

The tone should stay calm, practical, and nonjudgmental. Each reminder should make a clear invitation, explain the next useful action, and avoid urgency or pressure. Notification copy should not use emoji. The language should feel supportive enough for a mental health tool, but concrete enough that the user immediately understands why the reminder appeared and what tapping it will open.

## Permission And Control

Notifications are off until the user enables reminders and grants system notification permission. The app asks for permission only when reminders are being scheduled. If permission is denied, the settings screen explains that notifications must be enabled in System Settings before selected reminders can be delivered.

Users can turn reminders on or off as a group from Settings, then refine individual reminder types in Advanced Reminders. Individual toggles are available for mood check-ins, evening reflection, weekly reports, breathing resets, planned activities, course continuation, sleep wind-down, quote of the day, and life-event reminders. Scheduled reminder times are user-adjustable where the reminder type supports a fixed schedule.

## Privacy Posture

Notification scheduling is handled locally through Apple's notification system. The app does not need a server to send these reminders, and the reminder schedule is based on user settings and app data already stored on the device or in the user's private iCloud sync. Notification payloads should avoid exposing sensitive details unnecessarily. When a reminder references user content, such as a planned activity or active course, the copy should remain brief and action-oriented.

## Reminder Inventory

| Reminder | Default Timing | Purpose | Tap Destination | Current Notification Copy |
| --- | --- | --- | --- | --- |
| Daily Mood Check-In | 9:00 AM daily | Helps the user notice mood, intensity, body signals, and context while the day is still unfolding. | Mood Check-In | Title: "Check in with yourself" Body: "Take a moment to name your mood, intensity, and context. A quick check-in can make patterns easier to see over time." |
| Evening Reflection | 8:30 PM daily | Encourages a short review of the day so the user can identify what stood out, what was hard, and what may help tomorrow. | Evening Reflection | Title: "Reflect before the day closes" Body: "Look back with care: what stood out, what felt hard, and what would help you tomorrow?" |
| Weekly Report | 6:00 PM weekly, default weekday selected by the app calendar | Invites the user to review weekly trends, streaks, entries, achievements, and progress. | Insights | Title: "Your weekly insight is ready" Body: "Review mood trends, entries, achievements, and patterns from the week when you are ready to reflect." |
| Breathing Reset | 2:00 PM daily | Offers a short body-based pause during the day. | Breathing | Title: "Make room for one steady minute" Body: "Pause for a guided breathing reset to help your body settle before you continue." |
| Planned Activity | At each upcoming planned activity time | Reminds the user about activities they intentionally scheduled and encourages a small, adjustable first step. | Activity Planner | Title: "Your planned activity is coming up" Body: "[Activity name] is on your plan. If it still fits your day, begin with the first small step and adjust as needed." |
| Course Continuation | 4:00 PM daily when an active course exists | Helps the user return to an unfinished CBT course after they have already begun it. | Library | Title: "Continue your CBT course" Body: "Continue [course name] when you have a comfortable pocket of time for the next lesson or exercise." |
| Sleep Wind-Down | 9:30 PM daily | Supports a calmer end-of-day routine through reflection and closure before sleep. | Sleep Wind-Down | Title: "Begin your sleep wind-down" Body: "A quiet reflection can help your mind review the day, set down loose ends, and move toward rest." |
| Quote of the Day | 9:00 AM daily | Delivers one affirmation from the app's affirmation library. | Affirmations | Title: "Quote of the Day" Body: Uses the selected affirmation text. |
| Morning Intentions | 8:00 AM daily | Helps the user choose one grounded intention before the day gets busy. | Morning Intentions | Title: "Morning Intentions" Body: "Choose one grounded intention for the day before everything gets moving." |
| Before Work | 8:30 AM daily | Gives the user a brief breathing reset before entering work mode. | Breathing | Title: "Prepare with one steady minute" Body: "Take a brief breathing reset before work starts so you can arrive with a clearer body, a calmer pace, and one workable next step." |
| During Commute | 5:30 PM daily | Offers a transitional affirmation between parts of the day. | Affirmations | Title: "Reset between places" Body: "Open a short affirmation to leave the last stretch behind and bring your attention gently to what comes next." |
| Before Bed | 9:30 PM daily | Encourages a brief journal entry to close the day gently. | Journal | Title: "Close the day with care" Body: "Capture a few lines about what happened, what you handled, and what your mind can set down tonight." |

## Copy Principles

Each notification should answer three questions quickly: why now, what action is available, and how much effort is expected. The best reminders are specific without sounding demanding. They should use phrases like "take a moment," "when you are ready," "if it still fits your day," and "one small step" because those phrases leave room for user agency.

Avoid language that implies surveillance, diagnosis, failure, or urgency. Do not write reminders that say the app noticed the user is anxious, falling behind, doing poorly, or needs to fix something immediately. CBT notifications should support reflection and skill practice without turning the user's mental health data into pressure.

## Safety Boundaries

Notifications should never present themselves as crisis support. If a user may be in immediate danger, the appropriate path is emergency services or crisis resources, not a scheduled reminder. The notification system should remain focused on low-pressure self-help prompts: mood tracking, guided reflection, breathing practice, planned activities, learning continuity, and sleep preparation.

## Scheduling Behavior

Repeating reminders use local calendar triggers. Planned activity reminders are scheduled for future, incomplete planned activities and are refreshed when activities are added, completed, or changed. Quote of the Day schedules a rolling window of future daily notifications so each day can show a specific affirmation. Tapping a notification opens the relevant app area through an internal deep link.

If a reminder is disabled, pending and delivered notifications for that reminder type are removed. If all reminders are disabled from the main Settings toggle, the app cancels the currently managed reminder categories that toggle controls.
