# Follow along (after v1)

Follow along is **not** in the first release. The current live workout is the right v1 for someone starting gym who updates the phone between sets. Build this only after custom exercises are safe and a real-device acceptance pass has proven skip, fail, finish, and timers.

## Job

For someone with a known plan, the phone runs the session so they are not ticking every row. Logging stays authoritative. This is a second presentation of the same session — not a second data model.

## Mental model

**As planned unless you intervene.** Targets already on the set (plan + last-used weight) are what get saved when you confirm. Edit is always available. Auto-complete of a lift is never allowed.

## Same session, two presentations

Toggle on the live workout, or a second button on plan preview: **Start** (today’s list) vs **Follow along**.

- **Strength:** one large card — name, set i/n, weight/reps, **Done / Skip / Fail**, Edit numbers. No checkbox list. Rest ending does **not** mark the next set complete.
- **Timed (boxing):** current round full-screen. Start already starts work; at 0, log + rest (already built).
- **Rest:** full-screen countdown; at 0, advance to the next card + haptic. Do not complete the next set for the user.
- **Cardio:** one block card; Done when they get off the machine.

## Always available (full control)

Edit this set, Skip, Fail, Add set / Add exercise, **All sets** (today’s list), Finish / Discard, pause Follow along (drops to list). Switching modes mid-workout is allowed. `SetEntry` and `SessionTimer` stay the source of truth.

## Tap budget

A consistent strength session should be **one primary tap per set** (Done), plus optional edits. Rest and “what’s next?” should not need scrolling.

## Do not do

Estimated work-duration for lifts, auto-fail, or writing history you cannot open and change afterward.

## Implementation note

A `FollowAlongView` over the existing session. Do not rewrite `WorkoutSessionService`.
