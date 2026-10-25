# The Lake Car: a DroneBudz story arc

Status: plan for review, 2026-10-23. Owner: session B (narrative and systems), assets to Claude. This is a design document, not an implemented feature yet. It is written to fit the systems that already exist: the Discord-style DroneBudz server, the crew roles, photo metadata and evidence, the jobs and potential system, VidTube Studio, the phone apps and the notifications.

## 1. The pitch

A provincial police officer joins the DroneBudz server to ask the pilot for a small favour. There is an old blue estate car abandoned on the north shore of the lake, no plates, nobody claiming it. What starts as "get me a few photos of a car" becomes a six chapter, small town mystery about a man who left Halloway twenty years ago and has come back to finish something he started.

The tone is warm and human, not a crime thriller. The officer is new to the town, careful and a little out of her depth. The pilot is the person with the drone, the eyes in the sky, and the only one who can look at places the roads do not reach. There is no violence, no chase, no gore and no villain. The case is a welfare check that turns into a reunion, and the mystery is why Ellis Voss came back and whether he is all right.

The arc is optional and never interrupts the sandbox. The officer posts a message, the player can read it or ignore it, and the case waits. There are no real time deadlines and no fail states. A story switch already exists on the menu and the officer will honour it.

Working title: **The Lake Car**. Town: **Halloway**. Officer: **Constable Ada Rennick**, Provincial Police, Halloway detachment. Returning mechanic: **Ellis Voss**. Dog: **Biscuit**.

## 2. Promise to the player

1. The world stays a sandbox. The officer asks, she never orders. Every request can be declined or ignored and the case pauses, it does not fail.
2. Nothing is a timer. Chapters move when evidence is delivered and when an in game day passes, not when the player has been away.
3. The drone remains the player's. No new restrictions, no forced camera, no cutscene that takes control.
4. No fixed follower promises. A case video has follower and view potential like any other content, and the pilot decides whether to keep the evidence private or publish it.
5. The story uses the existing crew. Sam gives the weather window, Tom reports the lights he saw, Alex identifies the car and the bus, Riley knows the shore and the ranger rules, Jo knows the festival and Maya wants to cut the story.
6. People are treated kindly. The man at the lake is not a suspect, the officer is not a villain, and the ending is a community helping someone finish something.

## 3. Where it happens

The valley is already the playable space. Halloway is the town at the north end of the ridge road, beyond the railway. It does not need to be a full open world on day one.

- **The lake, north shore.** The abandoned blue estate, among the reeds, just off the old lakeside lane. Reachable by road and by drone.
- **The old garage, Halloway edge.** Voss and Son Motor Works, closed for twenty years. Roller door half open, workshop full of old tools, the festival bus under a tarpaulin. New location at the end of the ridge road, on a short spur.
- **The ridge camp.** A tent, a tarp, a camp stove and a dog, tucked in the trees near the railway, where Tom has seen a light. New evidence location.
- **Halloway itself, phase two.** A short high street: police house, pub, village hall, shop, bus stop, noticeboard. Built with Claude models later. Chapter 5 can use the existing festival ground and lake for the reunion without a full town.
- **The festival field.** Existing fireworks and festival setting. The last chapter returns there.

## 4. The people

### Constable Ada Rennick, Provincial Police, Halloway detachment
Thirties, transferred in from the city six weeks ago. Dry, polite, not a natural small town person yet. She says "this is a favour, not a case" and means it. She shares only what she needs to, thanks the pilot properly, and is careful about privacy. She joins the DroneBudz server as **Rennick**, with the role line "Provincial Police, Halloway". She becomes a recurring contact after the arc, dropping in every few in game days with a small local case.

### Ellis Voss
Seventies, mechanic, widower. Ran Voss and Son Motor Works and built the first festival bus. When the mill closed and the festival stopped he left Halloway. He has come back this autumn to finish the bus for the festival's return. He is proud, quiet and not looking for sympathy. His dog Biscuit goes everywhere with him. His old blue estate was his project car and he left it at the lake when the garage closed; he never reported it and never sold it.

### The crew's part
- **Maya** wants the story for the channel and will edit the case video, but she also knows when a story should wait.
- **Alex** identifies the car, the engine and the bus, and offers to help with tools.
- **Tom** saw the light on the ridge before the police did.
- **Sam** gives the weather windows for the evidence flights and the cold night at the camp.
- **Riley** knows the ranger rules on the north shore and the old garage lot, and is the one who says not to fly over the camp.
- **Jo** knows the festival committee and can find the bus a place in the parade.

### New minor voices (phase two, optional)
Nora Pike at the pub, Councillor Bain on the festival committee, the owner of the old garage lot. They stay as chat voices and noticeboard posts, not 3D characters on day one.

## 5. The story (spoilers)

Twenty two years ago Halloway had a mill, a festival and a garage. Ellis Voss ran the garage and built the festival's first bus, a green single decker that carried the festival committee and the town band. When the mill closed, the festival was cancelled and Ellis's wife Anne died the same winter. Ellis left town. He left his project car, a blue estate, on the north shore with a note in the glovebox that said he would come back for it.

The festival is returning this year. Ellis has come back quietly, camped on the ridge and started restoring the old bus in the derelict garage. He did not tell anyone. Constable Rennick, new in town, sees an abandoned car with no plates and no owner on record and asks the local drone pilot for help. The trail leads to the garage, to the name Voss, to the light on the ridge and to Ellis. The case is a welfare check, not a crime. The reunion is the festival, the bus, and a town that remembers.

The car's glovebox holds the original festival programme and a photograph of the committee with Anne in it. Ellis gives those to Jo for the festival archive. The pilot can photograph the bus's first run and either give the footage to the police and the family first, or publish it on VidTube for the channel. The story is not changed by the choice, but the crew remembers what the pilot did.

## 6. The chapter plan

Each chapter has the same shape: a message from Rennick (or a crew member), one clear request, an evidence flight, a reveal in the chat, a crew beat, and the next chapter unlocked after an in game day. The player can decline, and the chapter stays open.

### Chapter 0: A favour (the car)
- **Trigger:** 2 in game hours after the player's first job is published or first clip is uploaded (whichever comes first), and only if story jobs are on.
- **Who posts:** Rennick joins the server, then posts in #town.
- **Request:** Photograph the old blue estate on the north shore of the lake from three angles, close enough to read the rear and the wheel arches. Stay above the reeds. No plates visible.
- **Evidence:** subject `case_lake_car`, within 80 m, two photos.
- **Reveal:** No plates, no VIN on the dash, boot rusted shut. There is a tow sticker from Voss and Son Motor Works on the rear window.
- **Crew beats:** Tom says he has seen the car for weeks. Riley says the north shore is ranger land and the reeds are nesting ground. Maya: "That car is a story, not a job."
- **Reward:** none beyond the pilot's own photos; the case file opens. If published, the photo has normal view potential.

### Chapter 1: No plates (the VIN)
- **Trigger:** Chapter 0 evidence delivered and one in game day passed.
- **Request:** Get a close-up of the chassis VIN plate under the bonnet, and the tow sticker. The car is locked; from above, an open door is enough. A night shot with the torch is fine.
- **Evidence:** subject `case_lake_car`, within 15 m, at least one night or close detail photo.
- **Reveal:** VIN traces to a 1987 blue estate registered to Ellis Voss. No missing person report, no crime report. Rennick: "He is not in trouble. I would just like to know he is all right."
- **Crew beats:** Alex identifies the engine and the year. Sam gives the wind window for a low pass. Maya asks whether this is a story or a private thing.
- **Reward:** the old garage is marked as a new point of interest.

### Chapter 2: The garage (the name)
- **Trigger:** Chapter 1 delivered and one in game day.
- **Request:** Photograph Voss and Son Motor Works at the end of the ridge road, the roller door, the workshop window and the yard. Do not enter.
- **Evidence:** subject `case_garage`, within 60 m, two photos.
- **Reveal:** The workshop is not abandoned. There is fresh oil, a work light and a large object under a tarpaulin. Rennick: "Twenty years closed and someone is working in there. I need to know who."
- **Crew beats:** Jo remembers the garage and the first festival bus. Riley says the lot belongs to the town and the gate is open. Alex: "That is a bus under that tarp."
- **Reward:** the north shore car and the garage become discoveries; a case note in the Casebook.

### Chapter 3: Lights on the ridge (the watcher)
- **Trigger:** Chapter 2 delivered and one in game day.
- **Request:** Tom saw a light near the railway. Rennick asks for photos of the camp from a respectful distance, no people, no close pass. "If someone is living rough, I want to know he is safe, not move him on."
- **Evidence:** subject `case_camp`, photos from at least 30 m away. Any people present are marked in the Casebook and are not shared automatically.
- **Reveal:** Tent, tarp, stove, a dog and a folded festival programme. Rennick goes up to the camp herself the next morning.
- **Crew beats:** Sam warns about the cold night. Tom offers his own sighting time. Riley says the rangers will leave the camp alone. Maya: "Do not publish this one yet."
- **Reward:** the Casebook records a welfare note; Rennick's trust grows.

### Chapter 4: The man who fixed things (the bus)
- **Trigger:** Chapter 3 delivered and one in game day.
- **Request:** The garage door is open. Get aerial photos of the old festival bus inside and the yard, and one close photo of the name painted on its side. Do not photograph Ellis up close. Rennick has spoken to him and he has agreed to the photos of the bus only.
- **Evidence:** subject `case_bus`, two photos, one close detail of the lettering.
- **Reveal:** Ellis Voss, the garage and the bus. He is restoring the festival bus for the festival's return. The blue estate was his project car. He left it at the lake when he left and never reported it. Rennick: "There is no case here. There is a man who needs a hand with a bus."
- **Crew beats:** Jo offers the bus a place in the parade. Alex offers tools and a battery. Maya asks for the story, with Ellis's permission. Riley offers the old garage lot for the night.
- **Reward:** the Casebook moves to "helping", not "investigating".

### Chapter 5: The festival (the reunion)
- **Trigger:** Chapter 4 delivered and the festival is running (or the player starts the fireworks show), plus one in game day.
- **Request:** Film the bus's first run to the festival field. Photos or a short clip. This is the one the pilot can publish, with Ellis's and Rennick's permission.
- **Evidence:** subject `case_bus_festival`, one photo or clip of the bus moving, any distance.
- **Reveal:** The bus makes it. Ellis gives the pilot the original festival programme and thanks the crew. Rennick closes the file and says the detachment owes the pilot a favour. Jo puts the programme in the festival archive.
- **Reward:** a unique "Voss and Son" livery for one drone, or a carved wooden badge for the Casebook, a community fund payment, high follower and view potential for the video if published, and Rennick as a recurring contact with new small cases.
- **Crew beats:** the whole crew. Maya's cut of the story goes on VidTube. Alex's review of the bus. Tom's shot of the ridge. Sam's forecast for the festival. Riley's ranger note. Jo's parade.

### Epilogue: small cases, every so often
After the arc, Rennick drops into the server every 4 to 7 in game days with a one or two chapter local case. These are smaller and can be ignored:
- The wrong dog at the lake (a lost dog, a second dog, a case of mistaken identity).
- Crop circles in the barley (it is the village kids, and a photography opportunity).
- The missing festival sign (it was taken in for repair).
- The midnight mower (someone mowing the park out of hours, a kind neighbour).
- The railway ghost light (a reflection off a signal, or a farmer with a torch).
- The churns that went missing (borrowed for the pub's cheese night).
Each one uses one evidence flight, one chat chain and one small resolution, and reinforces the town as a living place rather than a crime scene.

## 7. How the player actually plays it

1. A notification from Rennick arrives while flying or after landing. The player can open #town in the DroneBudz app to read it, or ignore it.
2. The Casebook app shows the open request, the location hint, the photo or video evidence needed and what is already collected.
3. The player flies to the location from the request, frames the evidence with the camera, and the photo metadata tags the case subject automatically.
4. The Casebook marks the evidence as delivered. Rennick replies, the crew reacts, and the next chapter is scheduled for the next in game morning.
5. The player can publish any photo or clip on VidTube (with normal potential) or keep it for the case. The casebook marks which photos are private and which the player chose to publish.
6. When the case completes, the reward is unlocked, the officer becomes a contact, and the small cases begin.

The player is never asked to photograph a person up close. If a person is in frame, the Casebook flags it and the default is not to publish. The officer only asks for public, abandoned or outdoor places.

## 8. Systems needed

Existing systems to reuse:
- **ChatData / ChatApp:** add a new channel `#town` and a cast entry for Rennick. Officer messages are normal chat messages with a `case` tag.
- **Jobs and potential:** a case request is a job-like object with a giver, a brief, evidence objectives and no fixed rewards. Potential is shown in words, not numbers.
- **Photo metadata:** add case subject ids to the subjects in frame, plus a case tag so the Casebook can find the evidence.
- **PhoneNotes:** officer messages arrive as heads-up notifications and stay in the shade.
- **PhoneOS:** a new Casebook app, and the DroneBudz app gets the #town channel. The app grid grows to five apps or moves Jobs into the chat.
- **Crew:** Rennick is not one of the six and does not use the crew ask chips. The crew react around her.
- **WorldLife / discoveries:** new evidence landmarks (car, garage, camp, bus) and new discoveries for the garage and the north shore.

New systems to build:
- **StoryArc (game/story_arc.gd):** chapter state machine, current chapter, evidence flags, trust, day counters, decisions, persistence in `user://case_lake_car.cfg`, and a story on or off check.
- **Casebook app (game/casebook_app.gd):** chapters, requests, evidence thumbnails, officer notes, private or published marks, and a short "what next" line.
- **Case objects (game/case_objects.gd):** the abandoned car, garage, camp and festival bus, fixed positions, placeholder geometry until Claude models, with evidence subject ids and distance rules. Trees and props must keep clear of them and roads must not run through them.
- **Case channel and officer cast:** Rennick's messages, typing the officer's replies, and a small number of set piece chat chains.
- **In game day counter:** for pacing. The scene clock already has hours; a day count can be derived and stored.
- **Case video integration:** completed case jobs feed VidTube and the potential system like any other content, including an edited cut by Maya if the player chooses.

## 9. Phasing

### Phase 1: the spine (one or two sessions)
StoryArc state, Rennick and #town, Casebook app, first notification, chapter 0 with a placeholder car and a placeholder garage. Acceptance: the officer can be ignored, the case persists across restarts, the story switch stops it, gate passes, no change to the sandbox.

### Phase 2: evidence and chapters 0 to 2 (one or two sessions)
Placeholder car, garage and evidence tagging, chapters 0 to 2, casebook evidence thumbnails, discovery entries. Acceptance: photo evidence triggers chapter advances, restart resumes correctly, no case job can force a flight.

### Phase 3: the camp, the bus and the reunion (two sessions)
Camp, bus, chapters 3 to 5, crew beats, choice of private or published evidence, rewards and Rennick as a contact. Acceptance: the full arc can be played start to finish, and every chapter can be ignored without breaking the next.

### Phase 4: recurring cases and Halloway (later)
Small cases and a small town high street with Claude models: police house, pub, village hall, shop, noticeboard, bus stop. Acceptance: cases can appear and disappear without touching the core game.

## 10. Claude asset requests for the arc

- **Abandoned blue estate:** late 1980s estate car, faded blue, rust patches, missing plates, one flat tyre, open boot and a broken rear window. 2 variants, one with a tow sticker.
- **Police vehicles:** provincial police SUV and a plain saloon, low profile light bar, no weapons, no aggressive livery. 2 variants.
- **Voss and Son Motor Works:** old rural garage and workshop, roller door half open, office window, fuel pump, tyres, a yard gate. 2 variants.
- **The festival bus:** old green single decker bus, faded festival lettering, seats, a roof rack, 2 variants (before and after restoration).
- **Camp props:** small tent, blue tarp, camp stove, folding chair, dog bed, gas bottle, a dog (Biscuit), a toolbox, a sketchbook, a festival programme.
- **Evidence props:** police tape, cones, evidence markers, a clipboard, a camera, a notepad.
- **Halloway high street (phase 4):** police house, pub, village hall, shop, bus stop, noticeboard, benches, lamp posts.
- **The dog:** a medium collie cross, sitting, standing and lying variants.

## 11. Writing rules

- No em dashes and no timers in player facing text.
- The officer is polite, precise and a guest in the server. She asks, she does not order.
- No violence, no gore, no chase, no weapons drawn. The police are doing a welfare check, not hunting a criminal.
- The crew keep their own voices. Maya is professional and curious, Alex is practical, Tom is restless, Sam is precise, Riley is protective of the land, Jo is warm and organised.
- The player is never belittled for ignoring the case. The case waits.
- The story must still make sense if the player has the story switch off: nothing in the world changes until they turn it on.

## 12. Open questions for Robert

1. **Tone:** is the humane mystery and reunion the right direction, or do you want a real crime with higher stakes? I recommend the humane version because it fits the valley and the crew.
2. **Officer:** is Constable Ada Rennick the right name and rank, and should she be a woman, a man or left neutral? Is "Provincial Police, Halloway detachment" the right fictional force?
3. **Where she talks:** should Rennick post in a public `#town` channel, in a one to one DM to the pilot, or both? I recommend #town for the crew reactions and a DM for the private case details.
4. **Town size:** is the small Halloway edge (garage, police house, pub, hall) enough for phase one, with the town high street later, or do you want the town built first?
5. **Pacing:** should chapters advance after one in game day, or should the officer drop in every few in game days so the case feels like a recurring visit? I recommend one day early and longer gaps later.
6. **Evidence choice:** should the player be able to choose between handing evidence to the police privately (money, trust) and publishing it for the channel (followers, views), with the story continuing either way? I recommend yes, with no punishment for either.
7. **Rewards:** is the "Voss and Son" livery the right unique reward, or would you prefer a new gear item, a new place, or a festival flyover?
8. **Small cases:** should the recurring cases be warm and low stakes like the list above, or do you want a few of them to have a little more mystery?
9. **Story switch:** should the officer disappear entirely when story jobs are off, or stay in the server with the case paused?

## 13. First messages, draft

These are the first beats, in Rennick's and the crew's voices. They are not final copy.

**Server event:** Rennick joined the server.

**#town, Rennick:** Afternoon. I am Constable Rennick, new at the Halloway detachment. This is a favour, not a case yet. There is an old blue estate on the north shore of the lake. No plates, nobody has claimed it, and I would like to know whose it is before I fill in the paperwork. If one of you flies a drone, could you get me a few clear photos of the car and the ground around it? From above is fine. Do not land.

**#general, Tom:** That car has been there since before the storm. I thought it was the ranger's.

**#general, Riley:** It is not ours. And the reeds on that shore are nesting ground, so keep some height.

**#general, Maya:** A car with no plates and a police officer asking nicely. That is a story, not a job.

**#town, Rennick:** I would rather it was nothing. Photos today, please, and thank you.

After the first photos:

**#town, Rennick:** Thank you. No plates, and the boot will not open. There is a tow sticker on the back window, Voss and Son Motor Works. That garage closed before I moved here. Does that name mean anything to anyone?

**#general, Jo:** Voss. The old garage. He built the first festival bus.

**#general, Alex:** 1987 estate, if the shape is right. Someone looked after it once.

**#town, Rennick:** Then I have a name and a garage to look at. I will come back to you.

This sets up the case without turning the server into a police procedural, and it gives every crew member something to do with their own role.
