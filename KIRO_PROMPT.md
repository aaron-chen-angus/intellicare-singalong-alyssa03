# Kiro Prompt — intelliCARE Music Sing-a-Long · 城里的月光 Moonlight in the City (Alyssa Lie · Ep 03)

> Open this folder as the Kiro workspace:
> - read `ASSESSMENT.md` first;
> - the spec is in `.kiro/specs/singalong-alyssa01/` (`requirements.md` V1–V22, `design.md`, `tasks.md`);
> - put the audio stems in `audio/` (see `audio/PUT_STEMS_HERE.txt`);
> - the hero images are already in `assets/stage/` (`alyssa-hero-01.png`, `alyssa-hero-02.png`, `alyssa-portrait.png`), with the originals in `assets/`.
>
> Paste the text below into Kiro chat (Spec mode).

---

Build **intelliCARE Music Sing-a-Long** (repo `intellicare-singalong-alyssa01`, GitHub Pages): a gamified, karaoke-style sing-along web app that uses the device microphone on phones, tablets and computers. Follow `.kiro/specs/singalong-alyssa01/` and execute `tasks.md` in order, ticking tasks as you go.

**Song**
- Video: `https://d2yy42b28nebea.cloudfront.net/activity/Alyssa_Lie_Ep_03_-_20260311_0a1f7d2e_20260311_23d7d845.mp4`
- Performed by: **Alyssa Lie**
- Title: **城里的月光 | Moonlight in the City**. A cover; original by 许美静 Mavis Hee, words & music 陈佳明, 1995. Show the credit line.
- Lesson: **Ep 03 · Pitch Accuracy and Melody Flow / 音准与旋律流畅度**, aimed at seniors.
- `SONG_ID = 'moonlight-in-the-city'`
- "About this session" text (use verbatim; add a 中文 draft marked for my review): *In this reflective and melodic session, Alyssa performs the beloved Singaporean Mandarin classic 《城里的月光》, guiding seniors through the essentials of pitch accuracy and smooth melodic flow. She demonstrates how to navigate Mandarin pronunciation while staying in tune and connecting emotionally with the music. Through breakdowns and a guided sing-along, participants learn to maintain pitch stability and perform the melody with confidence and elegance.*

**What it does**
- The user watches the video and sings along. A **scrolling pitch lane** sits under the video and never covers it. It shows:
  - the singer's melody as note bars plus her real pitch contour;
  - the user's live voice as a glowing line, coloured by accuracy (octave-folded, so men, children and seniors can sing in their own octave).
- **Live cues:**
  - a tuner needle,
  - "▲ Sing higher / ▼ Sing lower" with the cents,
  - PERFECT / GREAT / GOOD / MISS with EARLY/LATE at the end of each note,
  - "Hold it", "Breathe", "Louder", "Steady!", "Nice vibrato!",
  - an optional guide tone and tap-to-hear target notes in Practice.
- **Scoring:**
  - per-frame pitch accuracy, a timing-lag search per note, stability on long notes, a vibrato bonus, and per-phrase expression (loudness correlation);
  - combo multiplier, golden notes, Spotlight Mode (×2), phrase bonus;
  - a final **Singing Score 0–100** = 35 % pitch + 15 % note hit rate + **15 % Melody Flow** + 10 % timing + 10 % stability + 10 % expression + 5 % coverage, with grades S–D and stars;
  - **Pitch Accuracy** and **Melody Flow** shown as the two headline gauges (the lesson focus).
- **Results:**
  - radar chart and a full-song pitch replay with scrub;
  - per-phrase table, flat/sharp bias histogram and range used;
  - coaching tips with "Practise this phrase";
  - optional local "Record my take" (never uploaded).
- **Modes:** Sing (ranked), Practice (phrase/A–B loop, speed, guide tone), Duet/Pass the Mic, Watch & Learn (no mic), Warm-up exercises, and Vocal Tests: Range Finder, Pitch Match, Breath Power (maximum phonation time). All tests are labelled non-clinical.

**Critical engineering decisions (see `ASSESSMENT.md`)**
1. **Reference melody is computed offline** from the lead-vocal stem (`audio/vocal.*`):
   - `tools/analyze_vocal.html` (pYIN-lite + Viterbi, segmentation, vibrato, phrases, golden notes, QA), run headlessly by `tools/run_analyze_vocal.ps1` with Edge, like the drum apps;
   - Colab fallback `tools/vocal_pipeline.ipynb` (Demucs + `librosa.pyin`);
   - align to the video by onset cross-correlation, then embed `vocalmap.json` inline.
   - If no stem is present yet, embed a clearly labelled synthetic demo map so the app runs end-to-end.
2. **Real-time pitch detection runs in an AudioWorklet** (YIN, 2048-sample window, 10 ms hop, clarity + RMS voicing gate). On the main thread: median filter, octave-jump guard, and latency compensation to song time.
3. **Two playback modes:**
   - **Video mode:** the video soundtrack plays.
   - **Stem mode**, when `audio/instrumental.*` exists: the instrumental and guide vocal play via Web Audio as the master clock, with the video muted and slaved to it. A guide-vocal slider runs from Duet through Assist to Karaoke (0 %).
4. **Microphone bleed and latency:**
   - Headphones mode is the default and required for ranked play.
   - A bleed check at session start drops the user to unranked if the mic can hear the music.
   - Latency calibration ("ta" on 8 clicks), stored per device.
   - iOS `audioSession` set to `play-and-record`; a Bluetooth warning.
5. **Privacy:** audio never leaves the device; only numeric metrics are sent, and only with PDPA consent.

**Song-specific features (requirements V25–V27, design §17):**
- **Melody Flow indicator:**
  - continuity through legato phrases, plus transition quality between notes (timing vs Alyssa's, overshoot, scoops);
  - live cues "Connect the notes / 连起来唱", "Glide smoothly / 滑顺一点" and "Lovely flow! / 很流畅！";
  - lit arcs between note bars, a flow ribbon on the results, and its own leaderboard, norm and dashboard charts.
- **Lesson-video structure:** the video mixes Alyssa **talking**, **breakdowns** and a **guided sing-along / performance**.
  - The analyser proposes `talk` sections (speech is never turned into notes) and echo windows; I confirm them in the Editor.
  - Talk sections show a "Listen to Alyssa" tip card and are not scored.
  - Breakdowns run as **call-and-response** (Listen → Your turn), scored as a separate sub-score.
  - Only the sing-along and performance sections count for ranked points.
  - A chapter strip seeks between the sections.
- **Pinyin under the 汉字 lyrics** (default on for Gentle). It comes from my `audio/lyrics_pinyin.txt` or from `pypinyin` in the Colab notebook.
- **Theme and progression:**
  - "Moonlight Mode / 月光模式" (star power) and "Moon notes";
  - rank titles 星光新手 → 月光传奇;
  - achievements Moonlight Melody, Steady Moon, City Lights;
  - senior-first defaults: Gentle difficulty and large lyrics.

**Demo / Stage mode (requirements V23–V24, design §16) — this is how I will demo it:**
- **Setup:** the audience hears **only Alyssa's original performance** through the laptop or external speakers. A volunteer sings into a USB or wireless mic, or a Bluetooth headset mic. Input and output are picked independently: the output picker uses `setSinkId` where supported.
- **The volunteer's voice is never sent to any output.** In Demo mode the mic monitor, take playback, guide tone and tap-to-hear are all disabled, the mic connects only to the analysis worklet, and a "🔇 Singer not amplified" chip shows in the HUD.
- **Stop Alyssa's voice from the speakers counting as the singer:**
  - a 3-step **room calibration** (quiet / speakers only / singer only) measures the speaker→mic gain, delay and the singer's headroom;
  - a **reference-aware bleed gate** compares each mic frame with the predicted bleed from a `mixDb` loudness envelope of the soundtrack, computed offline;
  - a **watchdog** raises the margin if leakage is detected.
- **Auto-sync** corrects wireless/Bluetooth mic latency from the per-note timing lags.
- **Ranking:** a demo run is ranked when the calibration headroom is ≥ 12 dB.
- **Audience-facing Stage layout** (≥ 1280 px): a big video, a large score and judgements, a "Now singing" banner, an auto-advancing results carousel, a local QR code to the app, and a rehearsal checklist.

**Reuse from my drum apps (copy and adapt; don't reinvent):**
- `intellicare-playalong-selina01` (or `intellicare-playalong-grace01`): song-scoped Storage, Settings/I18n, profiles (nickname, age, gender, plus a new singing-experience field) with consent;
- XP/levels/achievements/daily challenges/coins/cosmetics, leaderboards + `LeaderboardClient` (text/plain POST) + offline outbox;
- norms engine (literature values null + `verified: false`, never invented; cohort percentiles n ≥ 30), facilitator view, share card, hero stage, test harness, `cdp_run.ps1`/`shots.ps1`;
- and **the Apps Script backend with the Dashboard tab and the `?action=dashboard` web dashboard**, adapted to the vocal metrics (design §12–13).

**Same deployment pattern as the drum apps:**
- New Google Sheet + Apps Script Web App (Execute as Me, access Anyone); placeholders `__NEW_SHEET_ID__` / `__NEW_EXEC_URL__` keep the app local-only until I fill them in.
- Live leaderboards (Singing Score, Points, Pitch Accuracy, Combo, Duet, Pitch Match, Range, Breath Power) with age band / gender / week / season filters, global rank on the results screen, and dashboards of the vocal KPIs.

**Look:** the same family as the drum apps (dark stage, glass panels, neon glow, system CJK fonts):
- a **moonlight palette** matched to the hero photos: night navy `#0A1030`/`#141B45`, moonlight `#CFE3FF`, denim `#7FA6D6`, peach `#FFB199`, moon gold `#FFD98A`;
- accuracy colours green/cyan/amber/red;
- portrait-phone-first layout (header → video → HUD → pitch lane → lyrics → control bar with tuner and mic ring) and a two-column landscape layout;
- **both hero images** on the menu stage (tap to cycle, cross-fade, idle auto-alternate; tall-image aware), the portrait avatar in the header, 月光 ghost glyphs, a moon disc and a faint city skyline.

**README:** a Technical & Scientific Manual in the same standard as the drum apps:
- singing-accuracy science, YIN/pYIN/MPM/CREPE with equations, segmentation, octave folding, every scoring formula, latency and clock slaving, MPT, validity and limitations, and microphone privacy;
- APA 7 references from design §15 only, with additions marked `[to verify]`;
- every number must match the code.

**Constraints:** vanilla HTML/CSS/JS in one `index.html` (worklet inlined via a Blob URL) plus same-origin `audio/` files; no npm, no build step, no installs; Windows PowerShell + Edge for tooling; static GitHub Pages hosting (HTTPS is required for the mic).

**Verify:**
- `?test=1` 100 % (including synthetic-tone pitch tests ±2 ¢);
- screenshots at 360×740, 390×844, 1024×768 and 1440×900 with nothing over the video;
- the tone-singer self-test ≥ 98 % PERFECT; silence = 0 notes hit; the bleed check triggers on speakers with the guide on.

**When finished, give me:**
- the repo tree;
- `vocalmap` QA numbers and per-difficulty `maxPoints`;
- test results;
- the outstanding items: Alyssa's Chinese name (optional), the 中文 translation of the description to review, and the Sheet/exec IDs;
- the Demo rehearsal results (headroom, silent-volunteer false-accept %);
- my manual steps: stems in, Sheet + `setup()` + deploy, paste the URLs, enable Pages, Editor pass for section types (talk / breakdown / sing-along / performance), echo windows, lyrics timing, pinyin and Moon notes.
