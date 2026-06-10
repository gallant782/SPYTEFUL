# MindFrame Content Pipeline Workflow

This workflow describes how to automate script generation using the `script_generator.py` tool within an n8n or Make.com environment.

## Pipeline Architecture
1. **Trigger:** A scheduled trigger (e.g., daily at 9 AM) or a manual entry in the `content_backlog` table.
2. **Hook Selection:**
   - Fetch a hook from `HOOKS_DATABASE.json`.
   - Optionally filter by performance score or category.
3. **Template Selection:**
   - Choose a `template_id` (1-10) based on the content pillar or platform.
4. **Script Generation:**
   - Execute: `python3 script_generator.py --hook "[HOOK]" --template_id [ID] --mode gemini --api_key [KEY]`
   - Output: Structured script with VO and Visual cues.
5. **Database Update:**
   - Save the generated script into the `scripts` table for review.
6. **Voiceover Generation (Optional):**
   - Send the [VO] parts to ElevenLabs API to generate audio.
7. **B-Roll Selection (Manual/AI):**
   - Match [Visual] cues to assets in the media library.

## Commands
```bash
# Generate a prompt to paste into an LLM manually
python3 script_generator.py --template_id 1 --mode prompt

# Generate a script using Gemini and a specific hook
python3 script_generator.py --hook "99% of people are doing 'deep work' completely wrong." --template_id 1 --mode gemini

# Quick mock output for testing
python3 script_generator.py --mode mock
```

## Input Files
- `/home/team/shared/content/BRAND_VOICE.md`
- `/home/team/shared/content/CONTENT_TEMPLATES.md`
- `/home/team/shared/content/VIDEO_SPEC.md`
- `/home/team/shared/content/HOOKS_DATABASE.json`
