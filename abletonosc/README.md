# AbletonOSC: the Mantra additions

AbletonOSC lives at `~/Music/Ableton/User Library/Remote Scripts/AbletonOSC` (a clone of ideoforms/AbletonOSC). On
22.10.2026 handlers were added to its `abletonosc/application.py`; `mantra-application.patch` keeps them, so an update of
AbletonOSC cannot lose them. Put them back with:

    cd ~/Music/Ableton/User\ Library/Remote\ Scripts/AbletonOSC && git apply ~/Developer/ABLETON_LIVE_ACTIONS/abletonosc/mantra-application.patch

then send `/live/api/reload` (no Live restart). The handlers: `/live/application/view/arranger` (Opening and Closing
uses it at every start of Live), `/live/arrangement/midi_clip`, `/live/arrangement/add_notes`, `/live/arrangement/clear`,
`/live/arrangement/rainbow <track> [offset]`, `/live/application/browser/load_plugin`, `…/load_instrument`,
`…/list_plugins`, `…/load_uri`. Described in MANTRA_MANIFEST modules/ableton-live-audio.md.

- `/live/arrangement/audio_clip <file> [name] [position]`: a new audio track at the end of the set, named, the file on the Arrangement timeline (Live 12 Track.create_audio_clip); answers (track index, clips). 31.10.2026, the Gabrijela sample for Marko's effects.
- `/live/arrangement/warp <track> [0|1]`: the warp state of the clips on a track's timeline (count, then warping and warp mode per clip); with 0/1 switches warping off/on. 31.10.2026: the Gabrijela speech clip played "skipping" because Live had warped it in Beats mode at 120 BPM; a voice clip is never warped. `audio_clip` should place speech unwarped.
