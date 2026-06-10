# MindFrame Batch Production Guide

This guide outlines the workflow for producing high-retention short-form content in batches to maximize efficiency and maintain brand consistency.

## Phase 1: Content Selection
1. **Browse Hooks:** Open `HOOKS_DATABASE.json`. Select 5-10 hooks that align with your current campaign goal (e.g., Discipline, Productivity).
2. **Assign Templates:** Match each hook to a template from `CONTENT_TEMPLATES.md`. 
   * *Strategy:* Use "Myth-Busting" for contrarian hooks; "Pain Point" for relatable struggle hooks.

## Phase 2: Batch Script Generation
1. **Run the Generator:** Use the `script_generator.py` tool.
   * *Command:* `python3 script_generator.py --hook "[HOOK]" --template_id [ID] --mode prompt`
2. **Refine with LLM:** 
   * Copy the generated prompt into Claude or GPT-4o.
   * Use the **Master System Prompt** from `SCRIPT_GENERATOR_PROMPTS.md` as the system instruction.
   * Review the output. Ensure it follows the "one sentence per line" rule.

## Phase 3: Asset Specification
Every script in the batch must have the following attached before being sent to production:

### 1. Voiceover (ElevenLabs)
* **Voice Model:** Adam (Legacy or v2) or Antoni.
* **Settings:**
  * Stability: 45% (allows for more expressive delivery)
  * Clarity + Similarity Enhancement: 75%
  * Style Exaggeration: 0%
* **Direction:** Tell the generator to include specific [VO Direction] tags (e.g., *[Pause 0.5s]*, *[Lower tone]*, *[Emphasize "Framework"]*).

### 2. B-Roll Specification
* Use the styles defined in `VIDEO_SPEC.md`.
* For every line of VO, there should be a corresponding [Visual] tag.
* *Example:* `[Visual: Macro shot of a ticking analog watch, extreme slow motion]`

### 3. Text Overlays
* Specify text that should appear on screen (centered, Montserrat Extra Bold).
* *Example:* `[Text Overlay: THE COST OF LATER]`

## Phase 4: Output for Pipeline
Store the completed scripts in `/home/team/shared/content/scripts/batches/` using the following naming convention:
`YYYYMMDD_Batch_[CampaignName].md`

### File Structure:
```markdown
# Batch ID: 20260607_Mindset_01

## Script 1: [Hook Name]
- Hook: ...
- Script: ...
- Assets: [VO Settings, B-Roll List, Typography]

## Script 2: [Hook Name]
...
```

## Phase 5: Automation Hand-off
Once the markdown file is ready, the Systems Engineer's automation will:
1. Parse the VO lines → Generate Audio via ElevenLabs.
2. Parse Visual tags → Search stock footage library/API.
3. Combine audio, video, and text overlays in the editing software (CapCut/Premiere).
