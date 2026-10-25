# Side-job failure states and excellent outcomes

Status: implemented, 2026-11-15. The optional DroneBudz jobs now have different ways to go wrong and one way to go really right. The core story is unchanged: no story chapter can be failed by a photograph, and the sandbox keeps flying.

## The idea

A side job is a client's request, so it should react like a client:

- If the pilot gets too close to something they were told to keep clear of, the contact calls and pulls the job.
- If the subject is outside the useful distance range, the contact asks for a retake.
- If the subject is clipped at the edge of the frame, the contact asks for a retake.
- Three retakes for the same objective pull the job.
- If the shot is cleanly framed, inside the sweet distance band and has enough quality, the contact is genuinely delighted and pays a bonus.

Only accepted jobs are evaluated. Taking an unrelated photo, or ignoring a job, does nothing.

## Job requirements

| Job | Keep clear | Stay within | Frame | Sweet band |
|---|---|---|---|---|
| The lake at golden hour | none | 900 m | subject inside frame | 80 to 420 m |
| The chapel for the heritage page | 18 m from the graves | 400 m | subject inside frame | 35 to 180 m |
| Fireworks coverage | none | none | n/a | quality of the burst |
| The harvest postcard | 30 m from stock | 600 m | subject inside frame | 70 to 300 m |
| A favour: lake reading | none | 900 m | subject inside frame | 100 to 450 m |
| A favour: chapel handbill | 15 m from the graves | 500 m | subject inside frame | 30 to 200 m |
| A favour: field check | 30 m from stock | 700 m | subject inside frame | 80 to 320 m |
| The mill in detail | 14 m from the sails | 90 m | subject inside frame | 22 to 60 m |

The new mill job is reached after the harvest postcard. It is the clearest example of the three rules: too close and the estate pulls it, too far and the sails are a speck, and off-centre framing is clipped.

## Outcomes

### Too close: the job is pulled
The photo is rejected immediately and the job leaves the active list. The contact calls in the jobs channel, a note is posted and the jobs page shows it under pulled with the reason. No payout. Examples:

- Riley calls after the drone goes over the graves on the chapel job.
- Riley calls after the flock scatters on the field job.
- Jo calls after the estate reports the drone over the mill sails.

### Too far: retake warning
The subject is in the photo but outside the maximum distance. The contact asks for a closer shot and a note shows the retake count. Three warnings for the same objective pull the job.

### Out of frame: retake warning
The subject is in the photo but its centre is too close to the frame edge. The contact says it is clipped and asks for another frame. Three warnings pull the job.

### Excellent: a really positive response
A job gets the excellent grade when every subject is well inside the frame, the distance is in the sweet band and the photo quality holds up. The contact says it is better than the brief, a crew member comments in the channel, and the payout gets a 25 money bonus and extra followers. A published video records the grade.

### Normal and poor
A normal good shot gets the ordinary publication message. A poor but valid shot still publishes, with a smaller payout and a disappointed client line; it is not a failure.

## Why this only touches side jobs

The optional jobs are client work and can be pulled. The Lake Car chapters, Riley's wolf favour and the last flight are story beats and cannot be failed by a photo. The core story remains optional and safe; the only story constraint is the final flight's launch staging, which is about where the kit is parked, not a failure screen.

## Code

- `game/jobs.gd` holds the job requirements, the failure and retake state, the grading, the payout multiplier and the contact messages.
- `game/world_life.gd` and `game/case_objects.gd` add `frame`, `frame_margin` and `screen_r` to each named subject in the photo metadata.
- The jobs page shows the requirement line on offer and active cards, and a pulled line with the reason for failed jobs.
- Failure state is saved in `user://story.cfg` alongside the jobs state.

## Evidence

- `docs/realism/jobs/00_pulled_job.jpg`, the jobs page showing the mill job pulled for being too close.
- `docs/realism/jobs/01_offer_requirements.jpg`, an offer card with the distance and frame requirements.

## Honest limits

- The frame check uses the subject centre margin and its approximate screen size. A photo in which the subject is entirely outside the frame cannot be attributed to the job, so it is treated as an unrelated photo rather than a miss.
- The retake count is per objective and per mode. It persists across sessions and there is no abandon button yet.
- Pulled jobs do not return to the board. There is no retry offer, no appeal and no separate failure fee.
- The sweet distance band and the excellent threshold are simple constants, not a full photographic score.
- The client messages are canned per job; they are not generated from the actual frame.
- There is no on-screen framing or distance guide while shooting; the requirement line and the subject size are the only feedback before the shutter.
- No story mission uses these failure states.
