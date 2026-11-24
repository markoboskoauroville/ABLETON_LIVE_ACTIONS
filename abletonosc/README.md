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
- `/live/arrangement/clip_info <track>`: the first audio clip on a track's timeline: (track, file path, start in beats, start marker, end marker, warping, muted). 7.11.2026, Sync Track 2 to Track 1.
- `/live/arrangement/clip_mute <track> <0|1>`: every clip on the track's timeline deactivated (1) or active (0); the reference stays. 7.11.2026.
- `/live/arrangement/warp_markers <track> [mode b1 s1 b2 s2 ...]`: read the first audio clip's warp markers, or set warp mode (3 = Re-Pitch) and replace them by (clip beat, file seconds) pairs. Live refuses a marker that moves the audio less than ~30 ms in 128 ms. 7.11.2026, Sync Track 2 to Track 1.
- `/live/mantra/remote/state`: the whole picture for Ableton Live Remote (Mantra) in one question: playing, song time, tempo, metronome, loop, loop start, loop length, record mode, signature, song end (last_event_time), track count, then 9 per track (name, colour, kind bits 1 armable / 2 audio / 4 group / 8 grouped, arm or -1, mute, solo, audio clips, clip sum, volume). 24.11.2026.
- `/live/mantra/remote/clips <track>`: every audio clip on a track's timeline, sorted: (track, n, then per clip file path, start, end, start marker, end marker (seconds unwarped, beats warped), warping, muted, warp marker count, then beat/seconds pairs). 24.11.2026, the remote's waveform.
- `/live/mantra/start_time [beats]`: Live's insert point (Song.start_time, where Play and Space start), read or set. Setting `current_song_time` alone does NOT move it (24.11.2026: the remote's PLAY started from the old place).
- `/live/mantra/playback_mode [return|continue]`: Live's behaviour after ANY stop, kept in `~/.config/mantra-live-playback-mode`. A watcher on AbletonOSC's 100 ms tick (generation-guarded, so `/live/api/reload` does not double it): `return` (DAW) puts the playhead back on the insert point, `continue` (DaVinci Resolve) moves the insert point to where it stopped. The state answer now ends with the insert point and the mode (after the tracks). 24.11.2026.
- `/live/mantra/remote/song_dir <part>`: Song's attribute names containing <part> (a probe).
