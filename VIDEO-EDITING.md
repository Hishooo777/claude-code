# Video editing skills

Setup and test results for the five video-editing skill sources, checked on
2026-10-27 in a Claude Code cloud container (Linux x64, 4 CPUs, 15 GB RAM,
Node 22, Python 3.13, FFmpeg 6.1.1, no GPU).

## What is installed

| Source | Installed as | Where |
| --- | --- | --- |
| HyperFrames `embedded-captions` | retired upstream; replaced by the core `hyperframes` skill | `.claude/skills/hyperframes` |
| HyperFrames `talking-head-recut` | retired upstream; replaced by the core `hyperframes` skill | `.claude/skills/hyperframes` |
| HyperFrames core set (`npx hyperframes skills update`) | `hyperframes`, `hyperframes-cli`, `hyperframes-registry`, `media-use` | `.claude/skills/` |
| kajisho5/ffmpeg-skill 2.17.2 (`npx ffmpeg-skill --project`) | `ffmpeg-skill` | `.claude/skills/ffmpeg-skill` |
| nateherkai/herk-edit-kit | workspace with 15 skills | `/home/user/video-kits/herk-edit-kit` |
| digitalsamba/claude-code-video-toolkit | workspace with 13 skills and 15 commands | `/home/user/video-kits/claude-code-video-toolkit` |

HeyGen retired `embedded-captions` and `talking-head-recut` on 2026-10-21
(hyperframes PR #5651). Their guidance now lives in the `hyperframes` skill's
`references/captions.md` and `references/overlays.md`, and
`npx hyperframes skills update talking-head-recut` says so. The skills.sh
pages are older copies of the same content.

The skills in `.claude/skills` load automatically in any Claude Code session
in this repo. The two workspaces are meant to be opened directly: `cd` into
one and start `claude` there. This container is temporary, so in a new
session run:

```bash
scripts/setup-video-kits.sh
```

## Test results

The test input was a synthetic 17.5 s, 1080p talking-head clip: an espeak-ng
voice with two 2 s pauses, a botched take containing "um", and a clean
retake.

| Skill | Test | Result |
| --- | --- | --- |
| ffmpeg-skill | `doctor` | ok: 73 capabilities, none required missing |
| ffmpeg-skill | `silence.py` dead-air cut | 17.53 s to 13.28 s, both pauses found |
| ffmpeg-skill | `caption.py` burned SRT captions, then `look.py` | captions on screen at the right times |
| ffmpeg-skill | `fit.py` 9:16 blur pad, `render.py --template reels`, `check.py` | passes after `loudness.py --tp -2` (the robot voice peaks hard) |
| ffmpeg-skill | upstream `npm test` | all 1,159 tests that ran passed; 6 skipped (see the end of this file) |
| hyperframes | `doctor`, `browser ensure` | ready to render |
| hyperframes (captions) | transcript import, word-by-word animated captions, `check`, draft render | check passed; 13.2 s 1080p MP4 |
| herk-edit-kit | `npm ci`, `npm run setup`, `npm test` | 11/11 pass |
| herk-edit-kit | `npm run demo`, `hyperframes lint`, draft render | 0 lint errors; 8 s MP4 |
| herk-edit-kit | `cut-silences` on the test clip | 17.53 s to 13.69 s (needs FFmpeg 7, see below) |
| herk-edit-kit | `cut-mistakes`: candidates, review, apply, review page | retake removed, 9.0 s, `mistakes-review.html` written |
| video-toolkit | `examples/hello-world` Remotion render | 25 s 1080p MP4 |
| video-toolkit | `uv sync`, `verify_setup.py` | prerequisites ready; cloud not configured |
| video-toolkit | `cutdown.py` (9:16), `addmusic.py` | both work locally |

## Problems and workarounds

- **FFmpeg 6.1 cannot run Herk's cut scripts.** They pass
  `-/filter_complex`, which needs FFmpeg 7+. The setup script installs a static
  FFmpeg 7.0.2 at `/opt/ffmpeg7/bin`, and the Herk workspace's
  `.claude/settings.local.json` puts it first on PATH. It is not the global
  default because that build lacks `drawtext`, which ffmpeg-skill needs.
- **ffmpeg-skill warns about FFmpeg 6.1.1** (CVE-2026-8461, MagicYUV
  decoder). Ubuntu may have backported the fix. Avoid untrusted MagicYUV
  files until FFmpeg is 8.0.3 or newer.
- **Remotion cannot download its Chrome** (remotion.media is blocked here).
  Pass `--browser-executable` pointing at the pre-installed headless shell; the
  setup script prints the command.
- **cdn.jsdelivr.net is blocked**, so a new `hyperframes init` project that
  loads GSAP from the CDN fails `check`. Install `gsap` from npm and point the
  `<script>` at a local copy. The Herk demo already does this.
- **skills.sh is blocked**, so the official `npx skills add` path cannot run
  here. `npx hyperframes skills update`, the documented agent path, works.

## Missing requirements

Nothing paid was set up or used.

**Transcription (needed for automatic captions and transcript-driven cuts).**
Every engine is blocked or paid here. huggingface.co is blocked, so whisper.cpp,
Parakeet and faster-whisper cannot download models, and ElevenLabs Scribe needs
a paid key and its API host is blocked too. Until one of these is available,
give the skills a word-level transcript (.json, .srt or .vtt). On your own
computer, local whisper (`npx hyperframes transcribe`) is free.

**Optional paid or cloud services (not configured; I will ask before using any):**

| Service | Used by | Cost noted upstream |
| --- | --- | --- |
| ElevenLabs (Scribe, TTS, music) | Herk transcription; toolkit voice | your own credits |
| Kie.ai | Herk generated B-roll and images | your own credits |
| OpenAI / Groq / Gemini | Herk alternatives | your own credits |
| Modal (GPU) | toolkit `/setup`: TTS, FLUX.2, LTX-2, talking heads, upscaling | $30/month free on Starter, then pay as you go |
| RunPod | toolkit alternative GPU | pay per second |
| Cloudflare R2 | toolkit file transfer | 10 GB free tier |
| HeyGen | `media-use` avatars, voice, lipsync; `hyperframes cloud` renders | credits |
| YouTube Data API | toolkit `/publish` | free, needs OAuth |

**Optional free local extras:** Kokoro TTS and MusicGen (`hyperframes doctor`),
plus background removal. All three download models from Hugging Face, so they
cannot be installed here.

## ffmpeg-skill upstream test suite

`npm test` from the ffmpeg-skill 2.17.2 checkout, run against the system
FFmpeg 6.1.1. Every test that ran passed.

| Suite | Ran | Passed | Skipped |
| --- | --- | --- | --- |
| `tests/test_all.py` | 936 | 932 | 4 |
| `tests/test_contract.py` | 229 | 227 | 2 |

- One `test_all.py` test was interrupted by a time limit on my side, not by a
  fault in ffmpeg-skill. Run on its own, it passes:
  `test_picture.PictureTests.test_karaoke_style_default_sweep_is_byte_identical_to_omitting_the_flag`.
- Four skipped tests need Apple Silicon VideoToolbox encoders.
- One skipped test needs the 1.4 GB real-device media corpus
  (`tests/corpus.py --fetch`).
- One skipped test checks a `drawtext` line-break quirk in FFmpeg
  8.0–8.1.0, which this FFmpeg does not have.
