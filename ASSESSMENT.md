# Feasibility & Design Assessment — intelliCARE Music Sing-a-Long · 城里的月光 Moonlight in the City (Alyssa Lie · Ep 03)

**Purpose:** what is technically possible in a browser-only, GitHub-Pages-hosted, no-install sing-along app; the risks and how to mitigate them; the decisions taken; and what Aaron needs to supply. This document informs the Kiro spec in `.kiro/specs/singalong-alyssa01/`.

---

## 1. What the app must do

1. Play the performance video (CloudFront MP4) without covering it.
2. Capture the user's voice from the device microphone (phone, tablet or computer).
3. Show a **moving graph** comparing the singer's vocal line with the user's voice, in real time.
4. Score the user on singing-quality indicators, with karaoke-style **PERFECT / GREAT / GOOD / MISS** cues and corrective prompts ("▲ sing higher", "▼ sing lower", "hold it", "louder").
5. Be gamified to the standard of the two play-along apps: profiles, leaderboards, Google Sheets backend, dashboards, README manual.

## 2. Feasibility verdict

**Feasible with the browser only.** Every core capability (microphone capture, real-time pitch detection, scrolling pitch graph, scoring, Sheets backend) runs in modern Safari, Chrome and Edge with no installs.

The reference melody must be **pre-computed offline** from an isolated vocal track, exactly as the drum apps pre-compute the drum chart. Real-time separation of Alyssa's voice from the video's mixed audio is not realistic in a browser. It is also blocked anyway, because CloudFront sends no CORS header, so the page cannot read the video's audio samples.

## 3. How karaoke scoring works (the model we adopt)

Commercial and research karaoke scorers compare the singer against a reference on **pitch, volume and rhythm**. Tsai and Lee (2012) built an automatic karaoke evaluator on exactly those three feature families. Later work added vibrato and expression (Gupta, Li & Wang, 2018; Nakano, Goto & Hiraga, 2006).

We adopt a **template-based** design:

```
OFFLINE (once per song)
  vocal stem ──pYIN / CREPE──▶ f0 contour (10 ms) ──segment──▶ notes, phrases, vibrato, loudness
                                                            ──▶ vocalmap.json (inline in index.html)
RUNTIME (every frame)
  mic ──AudioWorklet──▶ YIN/MPM f0 + clarity + RMS (10 ms hop)
      └─ compare with vocalmap at song time (latency-corrected)
         ──▶ graph, live cues, per-note judgement, score, metrics
```

## 4. Indicators to measure

| # | Indicator | What it captures | Computed from | Shown live? | Scored? |
|---|---|---|---|---|---|
| 1 | **Pitch accuracy** | cents error to the reference | user f0 vs reference f0 per frame (octave-folded) | ✔ graph + tuner needle | ✔ main score (≈ 70 %) |
| 2 | **Note hit rate** | share of melody notes sung on pitch | per-note frame scores | ✔ judgement pop | ✔ |
| 3 | **Timing / rhythm** | entry and exit of each note vs the singer | user voiced-onset vs note start (ms) | ✔ EARLY/LATE | ✔ (≈ 15 %) |
| 4 | **Pitch stability** | steadiness on sustained notes | SD of cents within a note, after the attack | ✔ "steady" sparkle | ✔ bonus |
| 5 | **Vibrato** | rate (Hz) and extent (cents) on long notes | f0 oscillation analysis | ✔ wave icon | ✔ bonus when the reference has vibrato |
| 6 | **Voicing coverage** | singing when the singer sings, resting when she rests | user voiced frames vs reference voiced frames | ✔ "breathe" cue | ✔ (part of the note score) |
| 7 | **Dynamics / expression** | following the singer's loudness shape | correlation of user RMS (dB) with the reference envelope per phrase | ✔ loudness ribbon | ✔ (≈ 15 %) |
| 8 | **Range used** | lowest and highest notes sung | user f0 extremes | profile | ✗ (info) |
| 8a | **Melody Flow** (lesson focus) | smooth, connected (legato) singing: no unintended breaks; clean transitions without scoops or overshoot | user voicing continuity + note-to-note transition timing and shape vs the reference | ✔ lit arcs + cues | ✔ (15 %) |
| 9 | **Voice clarity** (experimental) | breathiness / periodicity | detector clarity (MPM peak) as an HNR proxy | ✗ | ✗ (info only) |

Out of scope for v1: lyric pronunciation and diction (would need speech recognition per syllable), and timbre similarity.

## 5. Key risks and mitigations

| Risk | Impact | Mitigation in the spec |
|---|---|---|
| **R1 Speaker bleed.** The mic hears Alyssa from the speakers and scores her voice as the user's | Inflated or false scores; leaderboard cheating | (a) **Headphones mode** = default and required for ranked play. (b) A **bleed check** at session start: 6 s of a vocal passage plays while the user stays silent; if > 15 % of frames match the reference, warn and switch to unranked "Speaker mode". (c) Browser `echoCancellation: true` in Speaker mode. (d) **Stem mode** (below) lets the user turn the guide vocal off. |
| **R2 Latency.** Mic input + output latency (30–250 ms, much more on Bluetooth) shifts the user's line late | Timing scores unfair; graph misaligned | Measure `AudioContext.baseLatency + outputLatency` and the mic track's reported latency. Add a **latency calibration** (sing "ta" on 8 clicks, take the median). Score pitch with ±150 ms tolerance search. Warn about Bluetooth. |
| **R3 Octave mismatch.** Men, children and seniors sing in a different octave from a female lead | Large cent errors for correct singing | **Octave-folded scoring** (pitch-class distance, the SingStar convention). The graph draws the user line transposed by whole octaves to the nearest reference. A Vocal Range test suggests the octave. |
| **R4 Pitch-detector errors** (octave jumps, noise, consonants) | Flicker, unfair misses | YIN/MPM with clarity threshold + RMS gate + median filter + octave-jump guard. Only score frames where the reference is voiced. Exclude the first 80 ms of each note (attack). |
| **R5 iOS Safari audio session.** With the mic active, playback can drop to the earpiece or a lower volume | Quiet music on iPhone | Set `navigator.audioSession.type = 'play-and-record'` where supported (Safari 16.4+). Tell the user to use headphones. Provide a video-volume boost slider. |
| **R6 No access to the video's audio** (CloudFront, no CORS) | Cannot mute only the vocal, cannot analyse in browser | Offline analysis from stems. Optional **Stem mode**: same-origin instrumental + vocal audio files drive playback with the video muted and slaved to the audio clock. |
| **R7 Privacy.** Microphone audio is sensitive | PDPA, trust | All audio is processed on the device. Nothing is recorded unless the user taps "Record my take" (kept locally). Only numeric metrics go to Sheets, with consent. |
| **R8 Performance on older phones** | Dropped frames, crackles | Pitch detection runs in an AudioWorklet (off the main thread). The graph is a Canvas 2D with a ring buffer. Adaptive quality, as in the drum apps. |

## 6. Two playback modes (important decision)

| | **Video mode** (works with only the MP4) | **Stem mode** (recommended; needs stems) |
|---|---|---|
| Audio source | video soundtrack (vocal always audible) | `audio/instrumental.*` + `audio/vocal.*` via Web Audio; video muted |
| Guide vocal | always on | slider 0–100 %; **"Karaoke" = guide off** |
| Clock | video `currentTime` (as in the drum apps) | `AudioContext.currentTime` is the master; the video is slaved (corrected when drift > 60 ms) |
| Bleed risk with speakers | high | low when the guide is off |
| Ranked play | headphones only | headphones, or speakers with the guide off after passing the bleed check |

**Recommendation:** ask the production team for the lead-vocal and instrumental bounces (the "D3 MASTER" naming suggests a multitrack session exists). The vocal stem is **required** for the reference melody anyway; the instrumental unlocks true karaoke.

## 7. Scientific add-ons (parallel to the drum apps' Reflex and Beat Sync tests)

1. **Vocal Range Finder:** lowest and highest sustained notes (≥ 1 s). The Seattle Singing Accuracy Protocol begins with a comfortable-range task for this reason (Demorest et al., 2015).
2. **Pitch Match Test:** hear a tone, sing it back; 10 trials within the user's range; outcome = mean absolute cents error. This is the single-pitch-matching paradigm used in singing-accuracy research (Demorest & Pfordresher, 2015; Pfordresher & Brown, 2007).
3. **Breath Power (Maximum Phonation Time):** sustain "ah" as long as comfortable, best of 3. MPT is a common, simple clinical measure of phonatory function, and older-adult data exist: Maslan et al. (2011) reported mean MPTs of about 21–23 s across the seventh to ninth decades, with no significant effect of age group or gender. Relevant to intelliCARE seniors; labelled non-clinical.

## 8. What Aaron needs to supply

| Item | Status | Needed for |
|---|---|---|
| Video URL | ✔ given | playback |
| **Lead-vocal stem** (`audio/vocal.*`) | **required** (Colab Demucs fallback from the video if unavailable — lower quality) | reference melody |
| Instrumental stem (`audio/instrumental.*`) | strongly recommended | Stem mode / karaoke |
| Song title | ✔ 城里的月光 / Moonlight in the City (cover; original 许美静, words & music 陈佳明, 1995) | identity |
| Alyssa's Chinese name | optional — omitted if not supplied | identity |
| Pinyin for the lyrics (`audio/lyrics_pinyin.txt`) | optional — otherwise generated by `pypinyin` in Colab | pinyin line for seniors |
| Lyrics (`audio/lyrics.txt`) | recommended | lyric line + karaoke wipe |
| Hero images | ✔ two supplied and pre-processed (`assets/stage/alyssa-hero-01/02.png`, `alyssa-portrait.png`) | menu stage, avatar |
| New Google Sheet (after the build) | later | live leaderboard and dashboards |

## 9. Reuse from the play-along apps

Kiro should reuse (copy and adapt) these proven modules from `intellicare-playalong-grace01` / `-selina01`:
- the layout shell,
- Storage, with **song-scoped keys** from the Selina port,
- profiles + PDPA consent,
- XP, levels, achievements engine, daily challenges, coins and cosmetics,
- leaderboards + the `LeaderboardClient` (text/plain POST),
- the offline outbox, norms engine and facilitator view,
- the share card,
- the Apps Script backend with the Dashboard tab and web dashboard,
- the stem-to-video alignment (onset cross-correlation),
- the screenshot and test tooling,
- the README manual structure.

The **new** parts: microphone capture, the pitch engine, the vocal-map pipeline, the pitch-graph renderer, singing scoring and cues, Stem mode, the vocal tests and the Vocal-Map Editor.

## References (APA 7)

- Demorest, S. M., & Pfordresher, P. Q. (2015). Singing accuracy development from K-adult: A comparative study. *Music Perception, 32*(3), 293–302. https://doi.org/10.1525/mp.2015.32.3.293
- Demorest, S. M., Pfordresher, P. Q., Dalla Bella, S., Hutchins, S., Loui, P., Rutkowski, J., & Welch, G. F. (2015). Methodological perspectives on singing accuracy: An introduction to the special issue on singing accuracy (Part 2). *Music Perception, 32*(3), 266–271. https://doi.org/10.1525/mp.2015.32.3.266 [to verify]
- Gupta, C., Li, H., & Wang, Y. (2018). A technical framework for automatic perceptual evaluation of singing quality. *APSIPA Transactions on Signal and Information Processing, 7*, e10. https://doi.org/10.1017/ATSIP.2018.10 [to verify]
- Maslan, J., Leng, X., Rees, C., Blalock, D., & Butler, S. G. (2011). Maximum phonation time in healthy older adults. *Journal of Voice, 25*(6), 709–713. https://doi.org/10.1016/j.jvoice.2010.10.002
- Nakano, T., Goto, M., & Hiraga, Y. (2006). An automatic singing skill evaluation method for unknown melodies using pitch interval accuracy and vibrato features. In *Proceedings of Interspeech 2006* (pp. 1706–1709). [to verify]
- Pfordresher, P. Q., & Brown, S. (2007). Poor-pitch singing in the absence of "tone deafness". *Music Perception, 25*(2), 95–115. https://doi.org/10.1525/mp.2007.25.2.95
- Tsai, W.-H., & Lee, H.-C. (2012). Automatic evaluation of karaoke singing based on pitch, volume, and rhythm features. *IEEE Transactions on Audio, Speech, and Language Processing, 20*(4), 1233–1243. https://doi.org/10.1109/TASL.2011.2174224 [to verify DOI]

---

## 10. Addendum — live demo with speakers (input: mic / wireless headset; output: speakers)

**Scenario:** viewers hear only Alyssa's original performance from the speakers. The volunteer sings into a mic and is not amplified.

**Effect on risk R1 (bleed):** bleed is now *expected*, not an error. Because a volunteer singing well in Alyssa's octave produces the same pitch as the leakage, pitch alone cannot tell them apart. The solution is **level-based, reference-aware gating**:
1. The offline pipeline stores the soundtrack's loudness envelope (`mixDb`).
2. A 20 s room calibration learns how loud the speakers are *at the mic* (gain, delay, spread) and how loud the singer is.
3. At runtime, a mic frame counts as the singer only if it is clearly louder than the bleed predicted for that instant.
4. A watchdog raises the margin if leakage still gets through, for example after someone turns the volume up.

**What makes it work in practice:**
- **Mic distance is everything.** A headset, lavalier or handheld mic at 5–10 cm gives 15–30 dB of headroom over the speakers; a laptop's built-in mic usually does not. The app measures and reports this ("headroom") and only ranks runs with ≥ 12 dB.
- Point the speakers at the audience, away from the mic. Don't change the volume after calibrating (or press Recalibrate).
- **Prefer a 2.4 GHz wireless mic with a USB receiver** over a Bluetooth headset. Bluetooth headset mics force the "hands-free" call profile (narrow-band, higher latency) and can pull the audio output to the headset. If Bluetooth is used, set the output to the speakers explicitly; the app warns if the output is wrong, and **auto-sync** corrects the extra latency from the singing itself.
- Turn off any OS "listen to this device" monitoring. The app itself never routes the mic to an output in Demo mode.

**Stage extras:** an audience-facing layout for projectors and TVs, a "Now singing" banner, a big-screen results carousel, a QR code so viewers can try it on their phones, and a rehearsal checklist.


---

## 11. Addendum — song and lesson specifics (城里的月光 · Ep 03 "Pitch Accuracy and Melody Flow")

1. **Lesson focus → scoring.** The Singing Score is re-weighted so that **Pitch Accuracy** (35 %) and the new **Melody Flow** indicator (15 %) lead. Both are shown as headline gauges. Melody Flow combines continuity through legato phrases with the quality of note-to-note transitions (timing compared with Alyssa's, overshoot, scoops). It is a heuristic engagement measure, documented with its equations in the manual.
2. **Lesson video ≠ plain song (new risk R9).** The episode contains speech and breakdowns. A pitch tracker turns speech into nonsense "notes", which would penalise users unfairly.
   - *Mitigation:* the analyser proposes `talk` sections (speech-like voicing statistics), which Aaron confirms in the Editor. Talk is never scored, and the user sees a "Listen to Alyssa" card.
   - Breakdowns become call-and-response practice (Listen → Your turn) with a separate sub-score.
   - Only the guided sing-along and performance count for ranked points, so every leaderboard entry covers the same material.
3. **Mandarin and seniors.** A pinyin line under the lyrics (from Aaron's checked file, or `pypinyin` in Colab), large lyric type, and Gentle difficulty by default. Mandarin consonant onsets cause short unvoiced gaps; the Melody Flow continuity threshold (120 ms) ignores these.
4. **Hero images.** Two transparent cut-outs, both tall, alternate on the menu stage. The palette is taken from the photos and the song (night navy, moonlight, denim, peach, moon gold).
5. **Credit.** The UI and README credit the original recording (许美静, 1995; words & music 陈佳明). Confirm that the performance and lyrics licences cover public web use before deployment.
