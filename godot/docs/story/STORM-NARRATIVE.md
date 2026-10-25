# Storms in the story: the weather as a clock, a clue and a mood

Status: design for review, 2026-11-02. This is the plan for weaving the storm and tornado events into the spooky, mysterious and investigative side of Halloway. It builds on The Lake Car arc and the crew roles. Nothing here changes the sandbox: storms remain optional, the drone is never damaged, and the story can be ignored.

## The idea in one sentence

The storms are not a separate minigame. They are the clock that moves the town's secrets, the thing that uncovers what was buried, and the reason the pilot has to go and look when everyone else stays indoors.

## What the storms already give us

- A real tornado and waterspout with a wind field, dust, debris, a roar and a camera exposure dip.
- Weather events the player can start from the menu, and weather the sky can turn into on its own.
- Sam's forecasts, Tom's storm chasing, the crew's storm chatter, and photo metadata that already records storm and night conditions.
- The Lake Car arc with Rennick, the Casebook, #town, evidence photography and the crew reacting in role.

We do not need a new weather system. We need the story to listen to the weather.

## Three storm threads for Halloway

### A. After the storm: the buried shelter (the main storm case)

The one that ties the storm to the town's history and to Ellis.

- **Trigger:** a tornado or a severe storm has passed over the valley after the story has started. Rennick posts in #town the morning after. The storm has scoured a field and left a square shape in the grass near the old lane.
- **First request:** a survey of the storm damage in the west meadow and around the farm lane, from the air. Photographs of the damaged fence, the fallen tree and the fresh earth. The Casebook adds a Storm watch card.
- **Second request:** the square shape is a buried storm shelter door. Photographs of the door and the stone steps after the storm, from a safe height. Rennick and Riley open it with the farmer.
- **The reveal:** a 1970s festival storm shelter, built after the big storm of 1974 when the town sheltered in the chapel. Inside is a storm diary kept by the festival committee, a box of old programmes, a child's drawing of the funnel that came through the valley, and a list of names. One name is Anne Voss. Ellis remembers the shelter. The town forgot it when the festival stopped.
- **The human turn:** Ellis and Jo take the archive to the festival. The shelter is cleared and marked as a place. The storm did not create a monster; it gave the town back a room it had lost.
- **Optional eerie note:** the diary's last entry is dated the day Ellis left town, and the handwriting is not the committee's. Nobody explains it. It is never made supernatural.
- **New places and evidence:** `case_storm_damage` (the scarred field and fence), `case_cellar_hatch` (the door and steps), `case_cellar_archive` (the diary and box). A new discovery place, the shelter, after it is opened.
- **Why it fits:** it uses the tornado as a finder, the farm and lane as places the player already knows, Ellis as the emotional centre, and Jo as the archivist. It also gives the storm a cost and a kindness.

### B. The bell in the rain (the spooky episodic case)

A shorter case for the space between bigger chapters.

- **Trigger:** during a storm, the chapel bell rings on its own and a light moves against the wind near the railway. Tom has seen it twice and has a note in his storm log. Rennick is new enough to be unsure and old enough not to say ghost.
- **Request:** during the next storm, get photographs of the chapel bell tower and the light on the ridge, from a safe distance in the rain. Night or storm conditions only.
- **What the pilot finds:** the bell rope is loose in the wind and has been tied in a knot that nobody admits to. The moving light is Ellis with a storm lantern, checking the bus roof and the garage after the wind, or a farmer checking a lamb. The shape on the fence is a coat.
- **The reveal:** almost everything has an ordinary explanation. The knot remains unexplained. Rennick writes it up as "wind damage to the bell rope" and the crew argue about it for a week.
- **Why it fits:** it is the campfire story version of the valley. No gore, no monster, no confirmation, just enough to make a storm night feel different. It also lets Sam, Tom, Riley and Maya each contribute in role.

### C. The storm glass (the archive mystery)

A quiet clue case that can run alongside A and B.

- **Trigger:** Rennick notices an old storm glass or barometer in the pub or the garage, covered in hand-marked storms going back to 1974. She asks for a photograph of it and the shelf around it.
- **Request:** a close photograph of the storm glass and the markings, and a look at the old record book beside it.
- **The reveal:** the marks line up with the storm years and with the buried shelter. One mark is not a storm at all: it is the year the festival stopped. The record book points to the shelter and to the chapel bell.
- **Reward:** a Casebook relic and a new rumour for the crew. It makes the storm history feel like a real local obsession.
- **Why it fits:** it turns a tiny prop into a story object and gives the pilot a reason to photograph the inside of a place rather than the sky.

## How the storm cases actually work

- **Weather events send signals.** WeatherEvents will emit when a storm starts, when a tornado touches down and when the storm clears. The story layer listens, not the other way round.
- **No forced weather.** The cases say "the next time a storm comes through". The player can wait, or start a tornado or thunderstorm from the menu. The story switch disables the storm cases entirely.
- **Evidence after the weather, not during.** The damage survey and the shelter are photographed after the storm has passed. The bell and the light are photographed during the next storm, because that is the point of them.
- **The storm can move the main arc.** If a storm arrives before the festival chapter, Ellis's first run waits for the weather to clear and the crew talk about it. If there is no storm, nothing is lost.
- **The Casebook grows a Storm watch section:** current storm case, evidence, and a short line on what the weather is doing. Rennick's storm messages and Tom's storm log live in #town and #weather.
- **The crew each have a storm part.** Sam forecasts. Tom has the ground truth and the log. Alex checks the structures and the bus. Riley handles access and land. Jo protects the festival schedule. Maya wants the footage and knows when not to use it.
- **Safety and tone.** The drone stays flyable, the wind is capped, nobody is hurt, and the police are not action heroes. The spooky is a mood and a local legend, not a horror film. The camera lens rain, the exposure dip and the roar do the atmosphere; the writing supplies the mystery.

## The first build slice

1. Add storm start, touchdown and clear signals to WeatherEvents.
2. Add a Storm watch card to the Casebook and Rennick storm messages in #town.
3. Build "After the storm" chapter 1: storm damage survey with placeholder debris, fallen tree, scoured earth and broken fence. No cellar asset needed yet.
4. Build chapter 2 with the buried shelter hatch and the archive, using placeholder models until Claude's set arrives.
5. Then the bell case and the storm glass, using the chapel, the railway and the pub/garage.

## Claude assets for the storm narrative

The tornado body is particle and shader driven and does not need a 3D funnel model. The useful models are what the storm leaves behind, and what the town hid from it.

### Priority 0: storm damage and the shelter
- `debris_plank_a/b`, `debris_roof_sheet_a`, `debris_shingle_a`, `debris_branch_a`, `debris_fence_a`, `debris_tin_a`, `debris_barrel_a`, `debris_feed_sack_a`, `debris_leaf_cluster_a` (tumbling debris pieces with a clear centre of mass, 0.3 to 3 m).
- `storm_damaged_barn_panel_a`, `storm_fallen_tree_a`, `storm_broken_fence_a`, `storm_scoured_earth_a` (a patch of torn ground and ditch), `storm_uprooted_post_a`, `storm_twisted_sign_a`.
- `storm_cellar_hatch_a` (a heavy wooden hatch, open and closed, with stone surround), `storm_cellar_steps_a`, `storm_cellar_wall_a` (low stone retaining wall), `storm_debris_field_a` (a scatter set of boards, sheets and branches).
- `storm_weather_station_a` (old wooden weather station with rain gauge and wind vane), `storm_rain_gauge_a`, `storm_glass_a` (barometer/storm glass on a wooden base), `storm_diary_a` (old leather book, open and closed), `storm_archive_box_a`, `storm_programme_a`, `storm_child_drawing_a` (folded drawing of a funnel, not scary).

### Priority 1: the bell case and the archive
- `chapel_bell_a` (bell, yoke and rope, with the rope as a separate swing node), `chapel_bell_rope_knot_a`.
- `railway_signal_lamp_a` (old signal lamp with a warm emissive lens), `storm_lantern_a` (hurricane lamp, lit and unlit), `storm_coat_fence_a` (coat over a fence post, reads as a figure from a distance).
- `festival_archive_box_a`, `old_map_a` (folded 1970s festival map), `storm_logbook_a` (Tom's notebook, open).
- `pub_storm_glass_shelf_a` or a small pub interior shelf if the pub front is built.
- `sandbag_a`, `storm_tarpaulin_a` for the festival's storm preparations.

### Priority 2: later storm cases
- `storm_cellar_interior_a` (a simple dark room shell with shelves, no gore), `chapel_interior_a` (small, simple), `railway_hut_a`, `flooded_ditch_a`, `fallen_power_line_a` (safe prop, no live wire effects), `storm_damage_road_sign_a`.
- `crowd_sheltering_a` (a few posed people under the marquee) and `crowd_storm_watching_a` (posed with coats), if the crowd set is being made.

### Technical notes for the storm set
- Same export contract as the rest of the story brief: glTF 2.0 `.glb`, metres, base origin, +Z forward, low poly with LODs, kit materials, vertex colours.
- Debris pieces should be centred on their own origin and roughly 0.3 to 3 m, so they can be tumbled in the existing tornado debris MultiMesh.
- Hatch, bell and rope parts need separate named nodes for opening and swinging. Colliders on the fallen tree, broken fence, shelter hatch and barn panel; none on debris, cloth or paper.
- Nothing gory, no bodies, no real police or town insignia, muted late autumn colours.

## Open questions for Robert

1. **Tone:** is the spooky-but-grounded direction right, with no supernatural confirmation, or do you want one thread that is genuinely unexplained?
2. **Trigger:** should storm cases wait for a real storm, or should Rennick ask anyway and the player can start a storm from the menu?
3. **Placement:** should the storm cases sit between the Lake Car chapters, or start after the main arc as the first recurring cases?
4. **The shelter:** is the 1974 festival shelter and the Anne Voss archive the right emotional link, or should the buried thing belong to a different part of Halloway's history?
5. **The bell:** is a loose rope and a lantern enough for the spooky beat, or do you want a stronger unexplained image (lights in the rain, a figure that is gone when the drone gets there)?
6. **The storm glass:** should it be in the pub, the garage or the police house, and how much of the archive should the pilot be able to photograph?
