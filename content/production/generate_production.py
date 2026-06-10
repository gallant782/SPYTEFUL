import json
import os

# Define the production format expansion
def expand_to_production(script_data):
    # This function takes a script and adds the requested production details
    # Pacing: ~140 words/min. 60s script = 140 words.
    # We'll simulate timecodes and search terms.
    
    production_package = {
        "id": script_data["id"],
        "hook": script_data["hook"],
        "pillar": script_data["pillar"],
        "template": script_data["template"],
        "performance_score": script_data["performance_score"],
        "eleven_labs": {
            "model": script_data["voiceover"]["model"],
            "settings": script_data["voiceover"]["settings"],
            "voiceover_text_with_timecodes": []
        },
        "video_production": {
            "b_roll_manifest": [],
            "text_overlay_frames": []
        },
        "distribution": {
            "hashtags": {
                "tiktok": ["#productivity", "#stoicism", "#discipline", "#mindset", "#motivation"],
                "instagram": ["#mindframe", "#deepwork", "#stoicmindset", "#productivitytips"],
                "youtube": ["#shorts", "#productivity", "#success", "#discipline"]
            },
            "thumbnail_concept": script_data["thumbnail_concept"],
            "cta": {
                "text": script_data["cta"]["text"],
                "link": "https://gumroad.com/mindframe/l/os-placeholder"
            }
        }
    }
    
    # Add timecodes and b-roll details
    current_time = 0.0
    for i, line in enumerate(script_data["voiceover"]["script"]):
        words = line.split()
        duration = len(words) * 0.45 # Rough estimate: 0.45s per word
        
        # VO with timecode
        production_package["eleven_labs"]["voiceover_text_with_timecodes"].append({
            "start": round(current_time, 2),
            "end": round(current_time + duration, 2),
            "text": line
        })
        
        # B-Roll
        # Handle cases where visuals might be shorter than script
        visual_idx = min(i, len(script_data["visuals"]) - 1)
        visual = script_data["visuals"][visual_idx]
        
        production_package["video_production"]["b_roll_manifest"].append({
            "timestamp": round(current_time, 2),
            "description": visual["b_roll"],
            "stock_search_terms": [visual["text_overlay"].lower(), script_data["pillar"].lower(), "cinematic", "minimalist"]
        })
        
        # Text Overlay
        production_package["video_production"]["text_overlay_frames"].append({
            "timestamp": round(current_time, 2),
            "text": visual["text_overlay"],
            "position": visual["position"],
            "style": "Archivo Black, White, Gold Highlight"
        })
        
        current_time += duration
        
    return production_package

# Load used hooks to avoid duplication
used_hooks = set()
for i in range(1, 4):
    with open(f"/home/team/shared/content/scripts/script_batch_0{i}.json", "r") as f:
        batch = json.load(f)
        for s in batch:
            used_hooks.add(s["hook"])

# Load all hooks
with open("/home/team/shared/content/HOOKS_DATABASE.json", "r") as f:
    hooks_db = json.load(f)["hooks"]

# Filter for unused hooks and sort by performance
available_hooks = [h for h in hooks_db if h["text"] not in used_hooks]
available_hooks.sort(key=lambda x: x["estimated_performance"], reverse=True)

# 1. Generate production_batch_01-10.json from script_batch_01.json
with open("/home/team/shared/content/scripts/script_batch_01.json", "r") as f:
    batch_01 = json.load(f)

prod_batch_1 = [expand_to_production(s) for s in batch_01]
with open("/home/team/shared/content/production/production_batch_01-10.json", "w") as f:
    json.dump(prod_batch_1, f, indent=2)

# Templates catalog for new scripts
templates_catalog = {
    "1": {
        "name": "The Truth About X (Myth-Busting)",
        "script_structure": [
            "Everyone tells you {topic} is the key to success. They're wrong.",
            "The reality is that {point1}.",
            "MindFrame protocol: {point2}.",
            "This is your asymmetric advantage.",
            "Stop following the crowd. Link in bio."
        ]
    },
    "2": {
        "name": "Why You're Stuck (Pain Point)",
        "script_structure": [
            "You're not stuck because you lack talent. You're stuck because you're addicted to {topic}.",
            "This creates a dopamine loop that keeps you reactive.",
            "MindFrame fix: {point1}.",
            "Break the loop today.",
            "Download the Frictionless OS. Link in bio."
        ]
    },
    "3": {
        "name": "The 3-Step System (How-To)",
        "script_structure": [
            "The {topic} system used by high-performers. It only takes 3 steps.",
            "Step one: {point1}.",
            "Step two: {point2}.",
            "Step three: {point3}.",
            "Join the 1% who execute. Link in bio."
        ]
    },
    "9": {
        "name": "The Hard Truth (Tough Love)",
        "script_structure": [
            "Stop lying to yourself. You're not busy, you're just {topic}.",
            "Busy-ness is a lazy substitute for focus.",
            "MindFrame Protocol: {point1}.",
            "High-performers do less, but better.",
            "Master your focus in bio."
        ]
    }
}

next_20_hooks = available_hooks[:20]
new_scripts = []
for i, hook_data in enumerate(next_20_hooks):
    script_id = f"mf-{41+i:03}"
    pillar = hook_data["category"]
    
    tid = str((i % 4) + 1)
    if tid == "4": tid = "9"
    template_info = templates_catalog[tid]
    
    # Simple logic to fill points
    point1 = "eliminating the non-essential"
    point2 = "building a fortress of focus"
    point3 = "executing with intensity"
    topic = hook_data["text"].split()[-1].strip(".")

    script_lines = [hook_data["text"]]
    if tid == "1":
        script_lines += [
            f"The world wants you to stay {topic}-focused and predictable.",
            "True sovereignty comes from breaking the established protocol.",
            "MindFrame rule: question every default setting in your life.",
            "This is how you win the asymmetric game.",
            "Join the 1% who see the truth. Link in bio."
        ]
    elif tid == "2":
        script_lines += [
            "Your brain is seeking the path of least resistance.",
            "But growth only happens in the zone of high friction.",
            "MindFrame protocol: seek voluntary discomfort every morning.",
            "Reclaim your edge.",
            "Get the OS in bio."
        ]
    elif tid == "3":
        script_lines += [
            f"Step one: Audit your current environment for {topic}.",
            "Step two: Eliminate the noise with clinical precision.",
            "Step three: Execute your primary mission without compromise.",
            "Velocity is the only metric that matters.",
            "Master the system in bio."
        ]
    else: # tid == "9"
        script_lines += [
            f"You are using {topic} to mask your lack of mission.",
            "True power is the ability to sit in silence and execute.",
            "MindFrame protocol: No distractions until the work is done.",
            "Own your attention or someone else will.",
            "Master your focus in bio."
        ]

    visuals = []
    for j, line in enumerate(script_lines):
        visuals.append({
            "b_roll": f"Cinematic {pillar.lower()} visual: " + line[:30] + "...",
            "text_overlay": line.split()[0].upper() + " " + (line.split()[1].upper() if len(line.split()) > 1 else ""),
            "position": "center"
        })

    s_data = {
        "id": script_id,
        "hook": hook_data["text"],
        "pillar": pillar,
        "template": template_info["name"],
        "performance_score": hook_data["estimated_performance"],
        "voiceover": {
            "model": "Adam (v2)" if i % 2 == 0 else "Antoni",
            "settings": {"stability": 0.35, "clarity": 0.75},
            "script": script_lines
        },
        "visuals": visuals,
        "cta": {"text": "Join the MindFrame movement.", "placement": "End screen"},
        "thumbnail_concept": f"Minimalist {pillar} icon on black. Text: {hook_data['text'][:15]}..."
    }
    new_scripts.append(expand_to_production(s_data))

# Save batches
batch_2 = new_scripts[:10]
batch_3 = new_scripts[10:]

with open("/home/team/shared/content/production/production_batch_11-20.json", "w") as f:
    json.dump(batch_2, f, indent=2)

with open("/home/team/shared/content/production/production_batch_21-30.json", "w") as f:
    json.dump(batch_3, f, indent=2)

# Generate ASSET_MANIFEST.md
manifest = "# MindFrame Asset Manifest\n\n| ID | Hook | Pillar | Score | Priority | Order |\n|---|---|---|---|---|---|\n"
all_prod = prod_batch_1 + batch_2 + batch_3
for i, s in enumerate(all_prod):
    priority = "High" if s["performance_score"] > 9.2 else "Medium"
    manifest += f"| {s['id']} | {s['hook']} | {s['pillar']} | {s['performance_score']} | {priority} | {i+1} |\n"

with open("/home/team/shared/content/production/ASSET_MANIFEST.md", "w") as f:
    f.write(manifest)

print("Production batches and manifest generated successfully.")
