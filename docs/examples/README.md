# Example guides

Two guides exactly as `pr.build` wrote them (contract v1), with no hand edits. Each came from one Muse Voice
Transcribe call and one Muse Spark 1.3 call, using the app's configuration.

| File | Source | Video | Steps |
| --- | --- | --- | --- |
| [faucet_from_app_recording.json](faucet_from_app_recording.json) | Recorded in the app (iOS simulator, glasses simulated with The Old Corona's CC BY video `yt_LPwPomA7BfM`) | 1:18 | 9 |
| [pottery_from_feed_video.json](pottery_from_feed_video.json) | Feed video `yt_pCqSCDIGiqM` (CC BY, see ATTRIBUTION.md) | 12:20 | 5 |

What to look at:

- `steps[].start_s` / `end_s` are the step's span in the source video, and `clip` is the padded span the app loops.
- `done_when` is the visible check that ends the step. `quote` is the instructor's own words, kept only if they
  appear in the transcript inside the clip. `provenance.dropped_quotes` lists the ones the post-processing removed.
- `inputs_provided` and `provenance.config` show what the model saw: video, transcript and on-screen text, no
  audio and no step names.
