# The Lake Car: the last flight and the end of the story

Status: design and implementation for review, 2026-11-04. This is the ending of the narrative in the game: the abandoned cabin, the 1980s police cruiser, the revelation that Constable Rennick has been dead for forty years, the lost hiker Wren, the thermal camera, the rescue, and the credits.

## What the player experiences

The Lake Car case closes with the festival bus and Ellis Voss. The unknown account has spent days asking questions and then goes quiet. A storm comes in. Constable Rennick comes back one last time and tells the pilot the truth.

- **The truth.** Rennick is not the new constable. She died in the spring of 1984 on an abandoned plot north of the lake, answering a call about a missing woman. The woman, Anne Voss, had gone for a drive on the stormy lake road and never came home. A pilot had reported lights near the lake and called it into the station. Rennick drove out that evening. Her 1980s provincial cruiser is still outside the cabin.
- **The unknown account.** The messages were never all from the officer. Wren, a hiker, got lost in the same storm and sheltered in the abandoned cabin. They found the old cruiser and the case file, and they used their phone to watch DroneBudz videos to work out where they were. The ghost of Rennick borrowed the phone and the signal. That is why the unknown knew too much, and why some of the messages sounded like a police officer and some sounded like a frightened person.
- **The last flight.** Rennick asks for one more favour: find Wren. The storm closes in. Alex fits a thermal camera to the drone. The officer's ghost leaves messages at three points on the way north. The cabin lights come on in the rain. Wren has already set out again on foot. The player uses the thermal camera to find the heat signature in the treeline, flies in close, and Wren is alive.
- **The ending.** The screen fades. The credits roll over the storm. The epilogue says what happened to Wren, Rennick, Anne and Ellis. The game is over.

## Why this closes the loops

- **The Lake Car:** the abandoned blue estate and the festival bus were Ellis's forty-year wait for Anne. Rennick's case was Anne's disappearance. The player closes both without ever meeting Rennick alive.
- **The unknown account:** Wren is the person behind the wrong-number messages. The officer's ghost is the reason the messages sometimes knew police detail and sometimes asked about the investigation. The thread is not abandoned; it becomes the rescue.
- **The camp and the shelter:** the storm cases planned in STORM-NARRATIVE.md already establish that storms uncover what Halloway buried. The finale uses the same idea on the personal scale: the storm uncovers the cabin, the cruiser and the truth.
- **The festival:** Ellis's bus and the festival give the town its warm ending. The cabin gives the officer hers. The two stories cross at Anne Voss.
- **The crew:** they stay behind. The last flight is the pilot alone with the ghost, the storm and the thermal camera, which is why it lands as an ending rather than another job.

## Adjustments made to the earlier story

The main arc already worked as a warm, humane case, so the ending does not rewrite it. It recontextualises it.

- Rennick's earlier lines no longer put her physically at the garage or the camp. Riley knocks on the door and goes up to the camp. The officer is a voice in the server from the start; the player only learns why at the end.
- The lake car, the garage, the camp, the festival bus and the reunion remain exactly as built.
- The unknown thread still starts as a wrong number and sows doubt about Rennick. The finale reveals the doubt was partly Wren reading the old case file and partly the officer testing whether the pilot would still come.
- The final unknown message now points to the cabin in the storm instead of the old shelter.
- The credits state the dates and the fates plainly. No gore, no body, no horror beat. The ghost is a person with an unfinished favour, not a monster.

## How it is built in the game

- **Trigger.** The finale waits until the Lake Car case is closed and the unknown account has sent its last message. After a short pause the storm starts and Rennick begins the reveal in #town.
- **Waypoints.** The finale watches the drone's distance to the cabin and posts ghost messages at roughly 700 m, 420 m and the cabin itself, so the player is never without a voice in the storm.
- **The cabin.** The abandoned cabin and the 1980s cruiser are always in the world and can be discovered before the finale. During the last flight the cabin windows and porch light come on, the hiker moves to the treeline, and the thermal signature appears.
- **Thermal camera.** A screen-space false-colour pass (warm ground orange, cold sky deep red and purple, hot bodies white) plus a heat signature on Wren that is only visible while the camera is on. Alex installs it at the start of the last flight. T toggles it.
- **The find.** With the thermal camera on, flying within about a hundred metres of Wren's heat signature ends the flight. The officer says thank you, Wren waves, the screen fades, the credits roll.
- **The ending.** A black full-screen layer with a short epilogue, the player's final follower, view, video and money counts, the credits, and THE END. Escape leaves the game. The world does not force a restart.
- **No fail state.** If the pilot flies away, the messages wait. The storm stays. The thermal camera stays installed. Nothing is timed.

## The assets the ending needs

The thermal effect is code. The cabin, cruiser, hiker, ghost and interior are placeholders until Claude's models arrive. The full request is in `CLAUDE-ENDGAME-ASSETS.md` and on the board.

### Priority 0
- **Abandoned cabin:** 1980s weatherboard cabin, storm-damaged roof, porch, door, two windows, lit and unlit window variants, a chimney and a woodpile. About 8 m by 6 m.
- **1980s provincial police cruiser:** boxy saloon, white body with a dark door and roof, faded lightbar, fictional HALLOWAY PROVINCIAL POLICE lettering, rusted sills, open driver door, separate wheels, simple interior. It should read as abandoned for forty years.
- **Wren, the lost hiker:** adult in a rain jacket and backpack, cold and turned around. Poses: standing with phone, sitting on the porch, walking with a torch, waving at the drone. Separate heat-mask body or a simple low-poly body that reads through the thermal camera.
- **Constable Ada Rennick:** 1980s provincial uniform, cap, duty belt without weapons, and a second, translucent ghost variant. A 1980s portrait for the case file.
- **Cabin interior:** bed, stove, table, chair, shelf, kettle, radio, calendar on 1984, case file, old map, lantern, boots, uniform jacket, a child's drawing of the storm.
- **Case file and police objects:** cardboard case file, 1980s notebook, pencil, torch, handheld radio, clipboard, police hat, a fictional badge, a blanket.
- **Thermal camera pod:** a small gimbal-mounted pod with a lens and a status light for the drone.

### Priority 1
- **Anne Voss's car:** the missing car, submerged or half-submerged in the lake, for the epilogue and a possible lake discovery. A simple wrecked estate with silt, weeds and a broken window.
- **Lake marker buoys and a police dive buoy** for the recovery.
- **Cabin exterior detail:** lean-to, log pile, axe block, tyre ruts, a fallen fence, an old police radio aerial, a storm lantern.
- **Wren's backpack and phone** as separate props for close evidence shots.
- **A rescue blanket** for the ending image.

### Priority 2
- **A second cabin interior layout** for variety.
- **A police dive van and a small recovery boat** for the epilogue montage.
- **A 1984 calendar and newspaper front page** with fictional text.
- **An old police radio set and aerial** for the cabin.
- **Wren's tent and hiking gear** for the search area.

## Open questions for Robert

1. Should the ending be final and quit to desktop, or should there be a "free flight" option after the credits?
2. Is the epilogue's Anne Voss link to Ellis the right loop, or should the missing woman be someone else?
3. Should the player be able to discover the cabin and cruiser before the finale and photograph them, or should they stay hidden until the ghost reveals them?
4. Should Wren be named and voiced in the chat before the reveal, or stay Unknown until the end?
5. Do you want the thermal camera carried into free flight after the story, or only during the last flight?
6. Is the ghost visually shown at the cabin (translucent Rennick) or only heard in messages?
