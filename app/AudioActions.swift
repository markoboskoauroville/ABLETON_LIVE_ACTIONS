// AUDIO: actions on the audio in the set (v19, Marko, 7.11.2026: "create this action which is going to sync ... every
// 20 seconds two tracks. So I don't need to use AI anymore. I can just put audio one on one track, audio two on the
// second track and they are going to be aligned after I press the action ... and finish at the same time", then "it is
// going to synchronize and then it's going to export two waves in the same length").
import Foundation

let AUDIO_ACTIONS = [
    Macro(name: "Sync Track 2 to Track 1", script: "audio_sync.py",
          about: "the same music heard by two recorders: the clip on track 1 is the master, the clip on track 2 is measured against it every 20 s (the rhythm of the sound, then the waveform to the sample), stretched onto track 1's clock (a recorder's dropout becomes a hard cut, never smeared) and exported: two WAVs of exactly the same length in a folder \"<track 1 file> SYNC\" next to it. RUN also puts the synced audio 2 on a new track under the master and switches the old clip off; CHECK only measures and reports"),
]
