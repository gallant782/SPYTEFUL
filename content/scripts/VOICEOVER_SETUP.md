# MindFrame Voiceover Setup Guide (ElevenLabs)

To maintain the MindFrame brand voice, all voiceovers must follow these technical specifications and workflows.

## 1. Recommended Voice Models
MindFrame uses deep, resonant, and authoritative male voices to convey stoicism and leadership.

*   **Primary Voice:** **Adam (v2)**
    *   *Characteristics:* Deep, grave, authoritative.
    *   *Best for:* Tough love, harsh truths, and high-performance protocols.
*   **Secondary Voice:** **Antoni**
    *   *Characteristics:* Clear, sophisticated, calm.
    *   *Best for:* System reveals, educational content, and mindset transformations.

## 2. Voice Settings (The MindFrame Preset)
Use these exact settings in the ElevenLabs Speech Synthesis panel:

| Setting | Value | Why? |
| :--- | :--- | :--- |
| **Stability** | **35%** | Lower stability allows for more natural, expressive inflection and "truth bomb" emphasis. |
| **Clarity + Similarity** | **75%** | High clarity ensures the voice sounds "in the room" and cuts through background music. |
| **Style Exaggeration** | **0%** | We want stoic realism, not a dramatic caricature. |
| **Speaker Boost** | **On** | Adds a slight professional sheen to the low frequencies. |

## 3. Batch Processing Workflow
For the automation pipeline (n8n/Python):
1.  Fetch the `script` array from `script_batch_01.json`.
2.  Iterate through each line.
3.  Send the text to the `https://api.elevenlabs.io/v1/text-to-speech/{voice_id}` endpoint.
4.  Append `[pause]` or `[0.5s pause]` to the text if the line needs a beat for emphasis.
5.  Save as individual `.mp3` files named by line ID (e.g., `mf001_line1.mp3`).

## 4. Script Timing & Duration
*   **Target Pace:** 2.5 to 3.0 words per second.
*   **Total Duration:** Most MindFrame scripts are 130-160 words, aiming for a **55-65 second** runtime.
*   **Silence:** Insert 0.5s of silence between points (Line 3, 5, 7) to let the "Truth" sink in.

## 5. Cost Tracking
ElevenLabs cost is roughly $0.0003 per character.
*   **Per Video (~1000 chars):** ~$0.30
*   **Per Batch (10 videos):** ~$3.00
*   **Monthly (30 videos):** ~$9.00

Monitor character usage in the ElevenLabs dashboard to ensure the subscription tier (Starter or Creator) matches production volume.
