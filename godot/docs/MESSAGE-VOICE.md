# Message voice and point of view

Status: message pass, 2026-11-15. The chat, phone notes and app notices now keep each character in their own voice. A character never refers to themselves in the third person, and an app notice is not written as if a friend said it.

## The voices

**Rennick, Halloway Valley Constabulary.** First person, concise, formal at first and warmer as the case moves. She asks, thanks, reports and apologises for herself, never says "the constable" about herself. Other people can use she and her when talking about her.

**Riley, park ranger.** Practical and protective. First person. Talks about the pasture, the flock, the graves and the trust. Does not narrate herself in the third person.

**Maya, editor.** Direct, dry, confident. First person. Talks about the cut, the followers and what the channel needs.

**Alex, tech.** First person. Props, gear, batteries, honest reviews.

**Sam, meteorologist.** First person. Forecasts, wind, cold nights and the lake reading.

**Jo, events.** First person. The festival, the committee, the parade and the bookings.

**Unknown.** Lower case, fragmentary, never fully explicit. Refers to Rennick as she, because the sender knows more about her than a stranger should.

**Kit, DroneBudz support.** First person support chat. Advice, controls, app paths, no story spoilers.

**Apps.** DroneBudz, VidTube, Facade, SkySync, Camera and the Casebook are apps and speak like apps. Their notices can be third person because they are not characters.

## The fixes

- The last-flight note from Rennick now reads: "Hey, buddy. I appreciate everything you have done for me. I have one more ask: fly north to the old cabin and find Wren. Please." It was "The constable has one more favour."
- The first case note from Rennick now reads: "I am new at the Halloway detachment..." It was "The new constable would like a word."
- The evidence note from Rennick now reads: "I have the photographs." It was "Rennick has the photographs."
- The night-pasture note from Riley now reads: "Finish the night pasture first, then the last flight. I need to know what is taking my sheep." It was a message from Rennick saying "Finish Riley's favour first."
- The trailhead note from Rennick now reads: "Drive the kit up to the ridge trailhead... I need you to start the last flight from there."
- The cabin note from Rennick now says she cannot see Wren from where she is.
- The phone notes from Rennick's ghost no longer title themselves "Rennick", which made "Rennick: Rennick" in the notification banner. The title is "A message".
- The job failure messages are now first person from the contact: "I called. You went right over the graves..." instead of "Riley called..."
- The Maya note now reads: "I am your editor now. Send the next clip to #clips and I will cut it before it goes up." It was "Maya is now your editor... she will edit it."
- Job notes no longer append "Open Flight > DroneBudz jobs to take it" to a friend's brief, and the ready-to-send note no longer says "Open Flight > DroneBudz jobs and hit Submit."
- Place discoveries now come from the DroneBudz app, not from Riley, because "You found the railway on the far ridge" is an app discovery, not Riley speaking.
- The Rennick chat role is now Halloway Valley Constabulary, matching the Casebook. Sam's contact role is METEOROLOGIST, matching his #weather voice.
- "The Pike jammer is off us now" is now "Pike's jammer is off us now. His hunter drones are not."

## Evidence

- The #town screenshot after the fix: `docs/realism/messages/00_town_voice.jpg`
- The phone note banner is covered by the HUD pass evidence; the note title now reads "A message".

## Honest limits

- This is a manual pass over the message strings and phone notes, not a dialogue system. There is no localisation, no voice acting and no branching personality model.
- App and Casebook status text is still third person on purpose because it is written by the app, not by a character.
- Rennick is referred to as she by the Unknown account; the case file does not otherwise specify gender.
- The saved `user://chat.json` can still contain older messages from previous sessions. The opening seeds are rebuilt, but old dynamic messages are not deleted or rewritten.
- The player's own messages are whatever they typed.
- The job board still uses a fixed set of contacts and formulas; the voices are authored strings, not generated dialogue.

## Questions for Robert

- MSG1. Is Rennick's "hey, buddy" the right level of warmth, or should she stay formal?
- MSG2. Should Rennick be she, he or they in the third-person references from the Unknown and the Casebook?
- MSG3. Should the job failure notes come from the contact's chat, the app, or both?
- MSG4. Should place discoveries stay app notices, or become Riley's messages again?
- MSG5. Should the player be able to answer these notes, or are one-way notifications enough?
