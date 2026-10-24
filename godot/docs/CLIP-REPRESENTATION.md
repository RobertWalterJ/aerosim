# Clips and VidTube without video files

Status: implemented, 2026-11-12. This is how video mode, rushes, Maya's edits and the VidTube video list work without storing a single full video file.

## The rule

Nothing in the channel system saves a video. No frame sequence, no audio track, no file in `user://`. A video in AeroSim is a **representative clip**: a small thumbnail, a duration, the flight metadata and a title. The player sees and feels the video through the thumbnail and the story; the game only stores the minimum needed to keep that fiction consistent.

## What happens when the player records

1. The player switches the shutter to video mode.
2. Pressing the shutter starts the recording indicator and the in-game REC timer, exactly as before.
3. Pressing it again captures one frame, takes a 480 x 270 JPEG thumbnail from it, and writes a clip record to `user://clips/index.json`. No full frame is stored, and no video file is opened.
4. A toast and a DroneBudz phone notice say the clip is saved, and how long it is.
5. The thumbnail appears in VidTube Studio under **RUSHES**. The home screen shows a small "N RUSHES" badge under the VidTube Studio icon.

The clip record is: an id, a thumbnail path, a duration, a title taken from whatever was in frame, a simple quality score, the flight metadata (clock, weather, night, subjects, drone, lens), and whether it has been used.

## What the player can do with rushes

- **Maya cut:** sends one rush to Maya. The result is a published video with the clip's thumbnail, a "Maya cut" title and the editor multiplier on views, followers and money.
- **Raw:** publishes the clip straight to VidTube with no edit bonus.
- **Send all to Maya:** strings every waiting rush into one video. The result carries the best thumbnail, the total duration, the number of clips and a larger quality bonus. That is the editor "stringing together" the footage, without rendering anything.

Once a rush is used it leaves RUSHES and becomes a video on the channel.

## What a published video looks like

VidTube Studio lists videos newest first in YouTube-like cards:

- a real thumbnail from the clip (or the source photo for older photo-based uploads),
- a play mark if no image is available,
- title,
- duration and clip count,
- "EDITED BY MAYA" or "DIRECT UPLOAD",
- views, followers and money earned.

The job-based videos still work as before and are now shown in the same card language. Photo uploads from the camera roll still use the photo as the thumbnail.

## Storage and caps

- Thumbnail: 480 x 270 JPEG at quality 0.82, typically 20 to 50 KB.
- Metadata: a few hundred bytes per clip in one JSON index.
- Cap: 80 clips; the oldest thumbnail is removed when the cap is reached.
- A one-minute recording costs one thumbnail, not one minute of video. A cut of five rushes costs five thumbnails and one record.
- No audio is stored, no images are written outside `user://clips`, and the camera roll is untouched by clip recording.

## Why this fits the valley

The channel is a story object, not a media pipeline. The thumbnail is what the player sees on the phone; the clip count and duration are what make a cut feel like work; Maya's edit changes the numbers and the tone of the card. The player is never asked to manage disk space or export a file to make the channel work.

## Honest limits

- The clip is not playable. There is no scrub, preview, trim or full-screen playback, because there is no video.
- One thumbnail represents each clip; there is no frame picker or custom thumbnail chooser yet.
- "Send all to Maya" uses the single best thumbnail, not a YouTube-style thumbnail montage.
- Multi-select and ordering of rushes are not implemented; a single rush can be cut, or all waiting rushes at once.
- Quality is a small formula from subjects, night, storm and fireworks, not a real edit score.
- The old photo-based upload path still exists alongside clips.
- The RUSHES section disappears when empty, leaving only the one-line explanation.

## Questions for Robert

- CLIP1. Should a cut use a collage of the best three thumbnails instead of one?
- CLIP2. Should the player be able to choose the thumbnail from a few captured frames?
- CLIP3. Should rushes be multi-select and ordered by the player before Maya cuts them?
- CLIP4. Should old jobs publish a thumbnail automatically from their qualifying photo?
- CLIP5. Should there be a short animated preview (a few frames) instead of a still, still without a video file?
