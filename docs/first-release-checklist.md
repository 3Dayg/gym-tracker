# Gym Tracker First-Release Checklist

## Ship call

Gym Tracker is not ready for a public App Store submission yet. The core offline session model is credible, but unit switching can mislabel saved values, the promoted boxing plan does not time work rounds, timed and mixed sessions are summarized incorrectly, and relaunch loses the visible rest countdown. First-run copy promises calories that do not exist, destructive actions are under-protected, and the app is missing a real icon plus privacy-manifest and policy work. Complete every **Now** item and the release acceptance pass before submitting.

## Now — must fix before submit

### - [x] 1. Make metric and imperial units trustworthy

- **User problem:** Choosing lb on first launch leaves the default `50` unchanged; changing units later relabels saved weights, speeds, distances, body weight, history, and PRs without conversion.
- **Why it matters:** A 100 kg lift becoming “100 lb” is silent data corruption from the trainer’s perspective.
- **Proposed change:** Call the setting “Units” with Metric/Imperial choices. Store values canonically or retain their original unit, convert the onboarding value immediately, convert all displayed/current values when the preference changes, and use unit-aware cardio defaults.
- **Where:** Welcome, Profile, Workout settings, plan editor, live workout, History, Progress, body-weight logging.
- **Effort:** L
- **Acceptance:** A trainer can log 100 kg and 5 km, switch to Imperial, see equivalent lb/mi values, switch back, and recover the original numbers within rounding tolerance.

### - [ ] 2. Make first launch optional, honest, and privacy-forward

- **User problem:** A trainer must enter height and weight before Quick Start, while the screen says calories will be estimated “later” even though no calorie feature exists.
- **Why it matters:** Mandatory health-adjacent data and unfinished copy create abandonment and trust risk on the first screen.
- **Proposed change:** Lead with “Your workouts stay on this iPhone—no account or internet needed.” Ask for units first, make height/body weight optional with “Skip for now,” explain that weight enables the optional trend chart, remove every calorie promise, and use realistic defaults for the selected unit.
- **Where:** First launch, Profile explanatory text, user guide.
- **Effort:** M
- **Acceptance:** A privacy-conscious user can reach Quick Start without entering body measurements; a user who enters them understands exactly where they are used.

### - [ ] 3. Make Boxing Conditioning usable without another timer

- **User problem:** The seeded plan specifies 3-minute rounds, but the app only records a duration after a manual check; it never times the work interval. Its 60-second coaching also conflicts with the global 90-second default.
- **Why it matters:** Boxing is a promoted ready-made plan, yet a boxer still needs another timer.
- **Proposed change:** Give timed rows a large Start/Pause control and visible work countdown. When work reaches zero, mark the round complete and start the configured rest. Set or clearly surface the plan’s intended 60-second rest before starting, while retaining manual completion.
- **Where:** Boxing plan start, live timed-exercise rows, rest bar.
- **Effort:** L
- **Acceptance:** A user can complete a 3:00 round and 1:00 rest with the phone as the only timer, including while locked or backgrounded.

### - [ ] 4. Make set outcomes and finishing unambiguous

- **User problem:** There is no clear way to skip or fail a set; unchecked rows silently disappear, Finish is disabled without explanation, and finishing gives no confirmation.
- **Why it matters:** This is the highest-frequency gym loop, often used one-handed and under fatigue.
- **Proposed change:** Add a visible Skip action; explain that a failed attempt should record actual reps completed, with an optional failed marker excluded from PRs. Before finishing, show completed and skipped/incomplete counts, then show a compact “Workout saved” summary and History link. Explain the empty Quick Start state and provide a clear discard path.
- **Where:** Live workout rows, empty active workout, Finish flow.
- **Effort:** M
- **Acceptance:** A trainer can log a partial failed set, deliberately skip another set, understand what will be saved, and verify the resulting workout.

### - [ ] 5. Preserve live-workout state across interruptions

- **User problem:** Sets survive a relaunch, but the rest countdown disappears while its notification may still fire; an old unfinished workout can reopen days later without context.
- **Why it matters:** Gym use includes locking the phone, taking calls, and app termination.
- **Proposed change:** Persist timer end time and session identity, restore or expire the timer on launch, and cancel stale notifications consistently. Show elapsed workout time and ask whether to resume or discard an unusually old session.
- **Where:** Workout tab, live workout, app relaunch/background lifecycle.
- **Effort:** M
- **Acceptance:** Cold relaunch during rest restores the correct countdown; reopening after expiry leaves no stale timer; reopening a day-old session asks what to do.

### - [ ] 6. Correct History summaries and protect saved work

- **User problem:** Timed workouts can show “sets · 0 kg,” mixed workouts hide lifting or cardio detail, and a swipe deletes a workout immediately.
- **Why it matters:** The first post-workout check makes Boxing Conditioning look broken and permits accidental permanent data loss.
- **Proposed change:** Summarize every modality present: sets and volume for strength, rounds and work time for timed work, and blocks/time/distance for cardio. Confirm or offer Undo for History deletion and surface a retryable error if finishing cannot save.
- **Where:** History list, session detail, workout finish persistence.
- **Effort:** M
- **Acceptance:** Strength-only, timed-only, cardio-only, and mixed sessions each show accurate summaries; an accidental deletion can be canceled or undone.

### - [ ] 7. Surface the instructions needed to follow a plan

- **User problem:** Seeded plan notes contain pace, rest, distance, and frequency guidance, but the start screen shows only a name and exercise count; broken plans can still start.
- **Why it matters:** “What do I do next?” is unanswered when the plan begins.
- **Proposed change:** Show a concise plan preview before start and a collapsible guidance block in the live workout. Include total exercises/sets or approximate duration, and block zero-exercise/broken plans with an Edit Plan action.
- **Where:** Workout plan list, plan editor, active workout.
- **Effort:** M
- **Acceptance:** A first-time user can understand and start either seeded plan without opening the documentation, and cannot start a plan that would produce an empty workout.

### - [ ] 8. Complete the minimum store and accessibility surface

- **User problem:** The app has no actual icon image, no privacy manifest/policy link, and custom workout controls/charts lack explicit accessibility support.
- **Why it matters:** The icon is a submission blocker; privacy declarations are release work; small unlabeled controls are poor one-handed and VoiceOver targets.
- **Proposed change:** Add the final 1024×1024 icon and simple launch treatment; add `PrivacyInfo.xcprivacy`; publish and link an on-device privacy policy; complete App Store privacy answers. Give controls at least 44×44 hit areas, meaningful VoiceOver labels/states/hints, Dynamic Type-safe layouts, chart summaries, and non-color-only completion cues.
- **Where:** App assets/configuration, Profile/About, live workout, charts, body-weight controls.
- **Effort:** M
- **Acceptance:** Archive validation accepts the icon and privacy manifest; the core workout can be completed with VoiceOver and large text without clipped or ambiguous controls.

## Next — high leverage for first-week use

### - [ ] 9. Add a lightweight first-workout orientation

- **User problem:** After onboarding, the user lands among five tabs with no explanation of Quick Start versus Plans or what empty History and Progress are waiting for.
- **Why it matters:** A trainer should begin within seconds and understand where completed work goes.
- **Proposed change:** Add a dismissible three-step card: choose Quick Start or a plan, complete sets, then find results in History and Progress. Turn empty states into actions such as Start Workout, Create Plan, or Log another weight.
- **Where:** First arrival on Workout; empty History, Progress, Plans, and filtered Exercises.
- **Effort:** S
- **Acceptance:** A new user can explain each tab and start either workout route without consulting the guide.

### - [ ] 10. Reduce one-handed logging and “what’s next?” friction

- **User problem:** Long workouts are one scrolling list; the completion circle is small, there is no overall progress, and notes/form cues are unavailable.
- **Why it matters:** The live screen is used repeatedly between sets, often one-handed.
- **Proposed change:** Enlarge completion targets, show completed/total plus the current or next exercise, de-emphasize completed rows, expose notes from section headers, and keep Add Set/Add Exercise reachable.
- **Where:** Active workout.
- **Effort:** M
- **Acceptance:** In a long plan, a trainer can identify and complete the next set with one thumb, read a cue, and add a set without hunting through the list.

### - [ ] 11. Close the loop when creating and editing plans

- **User problem:** Creating a plan immediately saves “New Plan,” backing out leaves empty templates, adding several exercises is repetitive, and starting requires switching tabs.
- **Why it matters:** Plans should remove setup friction rather than create it.
- **Proposed change:** Use an explicit Create/Cancel flow, support multi-select exercise adding, show an empty-plan call to action, add Start Workout to valid plans, and confirm plan deletion.
- **Where:** Plans list and plan editor.
- **Effort:** M
- **Acceptance:** A user can build a three-exercise plan in one pass, cancel without leaving debris, start it from the editor, and cannot erase it accidentally.

### - [ ] 12. Make custom exercises safe and understandable

- **User problem:** Built-ins appear swipe-deletable but nothing happens; duplicate custom names are allowed; changing a logged exercise type can invalidate old displays; deletion leaves broken plan rows.
- **Why it matters:** These dead ends can silently damage plans and progress.
- **Proposed change:** Offer delete only for custom exercises, warn on duplicate names, lock Type after history exists, and show affected plans before deletion or remove broken rows cleanly.
- **Where:** Exercise list, custom exercise editor/detail, affected plans.
- **Effort:** M
- **Acceptance:** Built-ins never advertise deletion, duplicates are caught, logged history remains readable, and deleting a custom exercise cannot leave a plan that silently skips work.

### - [ ] 13. Make Progress readable after the first workouts

- **User problem:** One-point charts look broken, body-weight trends lack guidance, estimated 1RM is unexplained, and cardio minutes and incline share a misleading scale.
- **Why it matters:** Progress is the reward for logging and should reinforce first-week use.
- **Proposed change:** Add one-point guidance, explain estimated 1RM, split cardio time and incline into labeled charts, remove the duplicate Profile entry, and use a searchable recent-exercise selector as the list grows.
- **Where:** Progress tab, exercise charts, body-weight section.
- **Effort:** M
- **Acceptance:** After one workout, the screen explains what is available and what needs another session; after several workouts, every chart has one clear metric/scale.

## Later — nice if time

### - [ ] 14. Add user-controlled backup and reset

- **User problem:** Fully offline storage means uninstalling or losing the phone loses every workout, and there is no in-app export or reset.
- **Why it matters:** Long-term trust declines as workout history becomes more valuable.
- **Proposed change:** Add a Profile data section with shareable CSV/JSON export, Delete All Data with strong confirmation, and clear no-account/no-sync copy.
- **Where:** Profile / Data & Privacy.
- **Effort:** L
- **Acceptance:** A user can create a readable backup and intentionally reset the app without hidden system steps.

### - [ ] 15. Add convenience controls after the core loop is stable

- **User problem:** Advanced users may want quicker weight changes, rest adjustments, workout reordering, and faster exercise selection.
- **Why it matters:** These improve repeat use but should not displace correctness and clarity.
- **Proposed change:** Evaluate weight +/− controls, rest +15/−15 seconds, live exercise reordering, and recent/favorite exercise shortcuts using observed gym use.
- **Where:** Live workout, rest bar, exercise picker, Progress.
- **Effort:** M–L
- **Acceptance:** Each addition measurably reduces taps without making the default screen denser or harder to use one-handed.

## Implementation order

- [ ] Phase 1: Fix canonical unit handling and revise onboarding.
- [ ] Phase 2: Correct History summaries, save errors, and destructive-action safety.
- [ ] Phase 3: Build timed-round control, rest restoration, and skip/fail/finish behavior.
- [ ] Phase 4: Surface plan guidance and improve one-handed next-set logging.
- [ ] Phase 5: Improve empty states, plan/custom exercise flows, and Progress clarity.
- [ ] Phase 6: Complete icon, privacy, and accessibility work.
- [ ] Phase 7: Run the clean-install release acceptance pass below.

## Release acceptance pass

- [ ] Complete or skip onboarding on a clean install.
- [ ] Verify Metric and Imperial logging and round-trip unit conversion.
- [ ] Start and finish each seeded plan.
- [ ] Complete a Quick Start workout.
- [ ] Log a partial/failed set and skip another set.
- [ ] Background, lock, and cold-relaunch during work and rest timers.
- [ ] Reopen and resolve a stale workout.
- [ ] Verify strength, timed, cardio, and mixed History summaries.
- [ ] Verify Progress after one workout and after several workouts.
- [ ] Create, edit, start, and delete a plan safely.
- [ ] Create, edit, use, and delete a custom exercise safely.
- [ ] Deny notification permission and verify clear fallback behavior.
- [ ] Complete the core workout with large text.
- [ ] Complete the core workout with VoiceOver.
- [ ] Validate the release archive, icon, privacy manifest, and App Store privacy answers.
