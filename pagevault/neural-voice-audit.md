# Neural read-aloud voice — audit

**Status:** Step 2 (the test build) is implemented in working source 0.12.0 (35), not yet built or
phone-tested. Akshat finds every iPhone system voice robotic, including Ava (Premium) on Build 34;
after listening to Kokoro demos he found them not robotic at all and asked for the test build and
then the PageVault integration. This file compares the options, records the choice and the path.
Sources checked 2026-10-05.

## Why the system voices stay robotic

`AVSpeechSynthesizer` can only use Apple's installed voices. Apps cannot use the Siri voices, and the
Enhanced/Premium voices are the best Apple offers to apps. PageVault already gives them clean text
(one passage per page, sentence ends kept). What is left is the voice itself, which no amount of
text clean-up changes. A different-sounding voice means a different engine.

## Candidates

| Option | What it is | Fits an iPhone, offline? | License | Verdict |
|---|---|---|---|---|
| **Kokoro-82M** (via sherpa-onnx, or MLX Swift / Core ML ports) | 82M-parameter neural TTS, 54 voices, 24 kHz; widely rated the most natural small open model | Yes. The int8 model is about 165 MB; published figures are roughly 3× real time on an iPhone 13 Pro (MLX) and RTF 0.08 on an iPhone 16 Pro, but these are other people's measurements, not ours | Weights Apache-2.0; sherpa-onnx Apache-2.0; its phonemizer data is espeak-ng (GPL-3.0), which is irrelevant for a personal sideloaded build that is not distributed | **Recommended to try first** |
| **Piper** (VITS voices, runs inside sherpa-onnx too) | Fast small neural voices built for Raspberry Pi | Yes, small (tens of MB a voice) and fast | Engine moved to GPL-3.0 (`OHF-Voice/piper1-gpl`; original `rhasspy/piper` archived 2025-10-06); each voice has its own terms, many personal/research only | Good fallback; noticeably less natural than Kokoro |
| **sherpa-onnx** itself | Not a voice: the on-device runtime (onnxruntime) with an official Swift package that runs Kokoro, Piper/VITS, Matcha and others | The way in for any of the above | Apache-2.0 | **The engine to use** |
| **Coqui XTTS-v2** | Large expressive model with voice cloning | No. Needs a GPU-class machine; far too heavy for real-time on a phone | Code MPL-2.0 (maintained by Idiap since Coqui closed in Jan 2024); the XTTS model is CPML, non-commercial only | Not for the phone; only as a laptop pre-render, see below |
| **Mozilla TTS** | The original project Coqui grew out of | Old models, archived | MPL-2.0 | Skip: superseded |
| Cloud (ElevenLabs, Azure, Google) | Best quality, needs internet | Streams over the network | Paid past small free tiers | **Ruled out**: it sends the book's text to a third party, breaks offline and local-only use, and costs money |

## How it would fit PageVault

- **Engine choice, not a replacement.** Keep the system voice and add a "Natural voice" option. If the
  model is missing or the phone is too slow, read aloud still works as today.
- **The voice is a file you import.** Bring the model in once through Files, like a PDF, rather than
  bundling it in the app. That keeps the IPA small, makes the voice removable, and matches Akshat's
  wish to import and remove voices. One Kokoro model holds all 54 voices.
- **Sentence-by-sentence synthesis, ahead of playback.** PageVault already splits each page into
  sentences with page offsets. The new engine would turn the next two or three sentences into audio
  ahead of time and play them back to back with `AVAudioEngine`. The tint moves per sentence, which
  is simpler than today's word-progress callbacks. Unlike the system voice, a neural voice does not
  sound robotic when given one sentence at a time.
- **Speed** is a model parameter: changing it re-renders the queued sentences.
- **Lock screen and background.** The audio background mode is already declared. Rendering ahead
  while audio plays is allowed in the background, but it costs battery: neural inference uses far
  more power than the system voice.
- **Build and CI.** Add sherpa-onnx's Swift package or prebuilt framework to `project.yml`, pinned by
  version and checksum, because this is a public repo pulling an external binary. CI can test the
  plumbing with a tiny model, but whether it sounds good is a phone-only check.
- **Pre-render alternative.** Render a whole book once on the Windows PC (Kokoro, or XTTS for personal
  use) into audio plus per-sentence timings, then import that next to the PDF. This gives the best
  quality and costs no phone battery. The trade-off is a step per book and large audio files, so it
  is a fallback if on-device turns out too slow or too hot.

## What the test build does (0.12.0 (35))

- The sherpa-onnx Swift package 1.13.8 (`project.yml`; its binaries are checksum-pinned by the
  package) links into AkshatOS. Nothing is downloaded by the app.
- **Voices screen → Natural voice (test):** Import voice folder… copies the unpacked
  `kokoro-int8-multi-lang-v1_0` folder from Files into `Application Support/PageVaultVoice`
  (outside PageVault's book folder, excluded from the phone's backup, replaced only once a new copy
  is complete), naming any missing part. Then: Read with the natural voice, a speaker picker (the 28
  English voices, Heart by default), Play a sample, Speed test, and Remove natural voice.
- **Speed test** renders a fixed three-sentence passage and prints seconds of speech, render time,
  the real-time factor, time to the first sentence, and whether that is fast enough.
- **Reading** keeps the narrator's page plan, skip, page turns, carry-over and lock screen; with the
  natural voice on, each page's passage is cut into one piece per sentence (words carried over a
  page break joined to the first), rendered up to three ahead on a background thread and played
  back to back with `AVAudioEngine`; the tint moves as each sentence starts. The speed menu has a
  Natural voice switch once a voice is installed; off, or with no voice, the iPhone voice reads.
- Known gap to measure: the first sentence of each new page is rendered only when the page before
  ends, so a short pause at page turns is expected; prefetching the next page is the fix if it
  shows.

## Recommended path

1. **Listen first, no code. Done:** Akshat finds Kokoro natural.
   Original step: Akshat listens to Kokoro voices (for example `af_heart`, `af_bella`,
   `am_michael`) and a Piper voice in a browser demo and says whether any is good enough. If none
   is, stop here.
2. **Spike.** A throwaway branch or test app on sherpa-onnx with the Kokoro int8 model. Measure on his
   iPhone: time to the first sentence, whether rendering keeps ahead of playback at 1× and 1.5×,
   memory, battery drain over 30 minutes, and heat.
3. **Build it into PageVault** only if the spike passes: voice import via Files, a Natural voice
   engine with sentence-ahead rendering, the system voice as a fallback, and tests for queueing,
   skipping and speed changes.

Open questions for Akshat: which iPhone model (it decides the speed margin), and whether about 165 MB
of storage for the voice is acceptable.

## Sources

- sherpa-onnx: https://github.com/k2-fsa/sherpa-onnx
- Kokoro via sherpa-onnx on iOS (spike app): https://github.com/a2sandoval/kokoro-tts-ios
- Kokoro MLX Swift port (iPhone speed figures): https://github.com/mattmireles/kokoro-swift-mlx
- Kokoro Core ML port: https://huggingface.co/mattmireles/kokoro-coreml
- Kokoro license and phonemizer: https://huggingface.co/hexgrad/Kokoro-82M/blob/main/README.md
- Piper's move to GPL: https://github.com/OHF-Voice/piper1-gpl
- XTTS license and the Idiap fork: https://github.com/coqui-ai/TTS/discussions/4145
