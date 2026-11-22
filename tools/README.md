# Tools

All scripts run on Windows PowerShell with Edge. If scripts are blocked: `powershell -ExecutionPolicy Bypass -File tools\<script>.ps1`.

## 0. The vocal map now embedded in index.html (made from the video, no stems)
1. `tools\prep_song.ps1`: extracts the lyrics from the Word file and downloads the performance video to `%TEMP%\alyssa_ep03.mp4` (offline analysis only).
2. `tools\scan_subs.ps1`: reads the burned-in orange lyrics every 0.2 s → `tools\_check\subs.json` and a crop sheet `subs_sheet.jpg` (check it: one crop per sung line).
3. `audio\lyrics.txt` / `audio\lyrics_pinyin.txt`: one line per **sung** line, in the order the video sings them (38 lines; the video skips the first 4 lines of verse 2).
4. `tools\extract_melody.ps1 -Embed 1`: matches lyric lines to the on-screen lines, extracts Alyssa's melody from the centre channel of the soundtrack, makes one note per sung character, fixes outliers with the repeated choruses, and embeds the map. Log: `tools\_check\melody.log`, picture: `tools\_check\melody.png`.
Accuracy: estimated from the MIXED soundtrack. Repeated lines agree within 1.2 semitones on average before the consensus step. If the production team supplies the dry lead-vocal stem, section 1 below gives exact notes.

## 1. Make the vocal map from a vocal stem (more exact)
1. Put the stems in `audio/` (`vocal.wav` required; `instrumental.*`, `lyrics.txt`, `lyrics_pinyin.txt` optional). Any of wav/flac/mp3/m4a. Keep stems ≤ 8 MB each for the web (mp3/m4a 160–192 kbps).
2. Run `tools\run_analyze_vocal.ps1`. It writes `tools\vocalmap.json`, a preview `tools\_check\preview.png`, prints the QA numbers and **embeds the map into `index.html`**.
3. QA gates (warnings are printed): voiced coverage 25–85 %, octave jumps < 1 per 10 s, ≥ 60 % of notes ≥ 150 ms, range ≤ 2.5 octaves.
4. **Review the sections.** The analyser proposes `talk` sections only; everything else is labelled `singalong (REVIEW)`. Edit the `sections` array in `tools\vocalmap.json` (type `talk` | `breakdown` | `singalong` | `performance`; optional `tip:{en,zh}`; for breakdowns add `echo:[{t0,t1,notes:[note indices]}]`: the listen notes are the indices, `t0` is where the learners repeat them). Re-embed with `tools\run_analyze_vocal.ps1` is *not* needed: paste the edited JSON between `<script type="application/json" id="vocalmap">` and `</script>` in `index.html`.
5. Lyrics: lines of `audio/lyrics.txt` are assigned to phrases in order (a warning is printed if the counts differ). Word timings (`words:[{t,w,py}]`) are not generated; without them the lyric line has no colour wipe.
6. `mixDb` is computed only when an instrumental is present (instrumental + vocal). For Demo mode, ideally compute it from the full video soundtrack (not automated yet).
7. `offsetMs` is 0: the stem→video alignment is not automated. If the stem starts later/earlier than the video, put the lag (ms) in `offsetMs`.
8. Run `tools\run_tests.ps1`. The tests assume the demo map's structure, so a real map will fail the map-specific ones; use them before embedding.

## 2. Other scripts
* `tools\run_tests.ps1`: `?test=1` in headless Edge, result in `tools\_check\test.txt`.
* `tools\shots.ps1`: menu / play / results screenshots at 360×740, 390×844, 1024×768, 1440×900 in `tools\_check\`, plus layout numbers and a JS error log.
* `tools\cdp_run.ps1`: generic "open URL, wait for title DONE, evaluate an expression" helper.

## 3. Deploy
1. New Google Sheet, Apps Script Web App (Execute as Me, access Anyone) — **backend not written yet**.
2. Put the `/exec` URL into `Config.SHEETS_ENDPOINT` (currently `__NEW_EXEC_URL__`, which keeps the app local-only).
3. Enable GitHub Pages on the repo root.

## 4. Backend contract (what the client already sends)
* `POST text/plain` `{"action":"submit","song":"moonlight-in-the-city","version":"…","session":{…}}` — `session` has the fields in `design.md` §12 plus `melodyFlow, continuity, transitionQ, breakdownScore, sectionScope`. Only ranked sessions of consenting players are queued. Response `{ok:true}` or `{ok:false,error}`.
* `GET ?action=leaderboard&song=…&board=singing|score|pitch|flow|combo|duet|pitchmatch|range|mpt&difficulty=…&age=…` → `{ok:true, rows:[{nickname,value}]}`.

## 5. Rehearsal script for the live demo (V24)
1. Settings → Demo checklist (7 items). Choose speakers as output, the mic as input, set mic mode **Demo / Stage**.
2. Run the room calibration at show volume; aim for headroom ≥ 12 dB (mic 5–10 cm from the mouth, speakers pointing at the audience).
3. Silent volunteer for a full chorus: < 2 % of reference-voiced frames accepted and 0 notes GOOD or better. (`?debug=1` shows live f0/clarity/RMS and "mic→dest: no".)
4. Volunteer sings: line visible on ≥ 80 % of sung frames. Bluetooth mic: expect timing to converge within ±60 ms by the second chorus (auto-sync).
5. Do not change the volume after calibration, or press Recalibrate in the pause menu.
**These rehearsal numbers have not been measured yet** (they need the real stems and your hardware).
