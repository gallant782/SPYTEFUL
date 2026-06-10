import os
import json
import argparse
import re
import urllib.request
import urllib.parse

def load_file(filepath):
    with open(filepath, 'r') as f:
        return f.read()

def parse_templates(content):
    templates = {}
    pattern = r'## (\d+)\. (.*?)\n(.*?)(?=\n##|$)'
    matches = re.finditer(pattern, content, re.DOTALL)
    for match in matches:
        t_id = match.group(1)
        t_name = match.group(2)
        t_body = match.group(3)
        
        template_data = {'name': t_name}
        
        # Point 1-3
        p1 = re.search(r'\*\*Point 1:\*\* (.*)', t_body)
        if p1: template_data['point1'] = p1.group(1)
        p2 = re.search(r'\*\*Point 2:\*\* (.*)', t_body)
        if p2: template_data['point2'] = p2.group(1)
        p3 = re.search(r'\*\*Point 3:\*\* (.*)', t_body)
        if p3: template_data['point3'] = p3.group(1)
        
        cta = re.search(r'\*\*CTA:\*\* "(.*?)"', t_body)
        if cta: template_data['cta'] = cta.group(1)
        
        templates[t_id] = template_data
    return templates

def generate_prompt(hook, template_id, brand_voice, video_spec, templates):
    template = templates.get(template_id, templates.get('1'))
    
    prompt = f"""
You are the MindFrame Content Architect. Generate a high-retention 30-90s video script.

BRAND VOICE:
{brand_voice}

VIDEO SPECIFICATIONS:
{video_spec}

TEMPLATE STRUCTURE ({template['name']}):
Hook: {hook}
Point 1: {template.get('point1', '')}
Point 2: {template.get('point2', '')}
Point 3: {template.get('point3', '')}
CTA: {template.get('cta', '')}

INSTRUCTIONS:
1. One sentence per line for [VO].
2. Include [Visual] and [Text Overlay] cues.
3. Tone: Direct, Stoic, Authoritative. No fluff.
4. Total words: 130-180 (for 60-90s).

OUTPUT FORMAT EXAMPLE:
[Visual: Dark cinematic stock, stoic statue]
[Text Overlay: THE TRUTH]
[VO]: Stop reading books. Start implementing them.
"""
    return prompt

def call_gemini(prompt, api_key):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
    data = {
        "contents": [{
            "parts": [{"text": prompt}]
        }]
    }
    body = json.dumps(data).encode('utf-8')
    req = urllib.request.Request(url, data=body, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req) as f:
            resp = f.read().decode('utf-8')
            return json.loads(resp)['candidates'][0]['content']['parts'][0]['text']
    except Exception as e:
        return f"Error calling Gemini: {str(e)}"

def main():
    parser = argparse.ArgumentParser(description='MindFrame Script Generator')
    parser.add_argument('--hook', type=str, help='The viral hook to use')
    parser.add_argument('--template_id', type=str, default='1', help='Template ID (1-10)')
    parser.add_argument('--mode', choices=['prompt', 'gemini', 'mock'], default='prompt')
    parser.add_argument('--api_key', type=str, help='Gemini API Key')
    
    args = parser.parse_args()
    
    base_path = "/home/team/shared/content"
    brand_voice = load_file(f"{base_path}/BRAND_VOICE.md")
    templates_content = load_file(f"{base_path}/CONTENT_TEMPLATES.md")
    video_spec = load_file(f"{base_path}/VIDEO_SPEC.md")
    
    templates = parse_templates(templates_content)
    
    if not args.hook:
        hooks_db = json.loads(load_file(f"{base_path}/HOOKS_DATABASE.json"))
        import random
        args.hook = random.choice(hooks_db['hooks'])['text']
    
    prompt = generate_prompt(args.hook, args.template_id, brand_voice, video_spec, templates)
    
    if args.mode == 'prompt':
        print(prompt)
    elif args.mode == 'gemini':
        api_key = args.api_key or os.environ.get('GEMINI_API_KEY')
        if not api_key:
            print("Error: API Key required for gemini mode.")
            return
        print(call_gemini(prompt, api_key))
    elif args.mode == 'mock':
        print(f"""
[Visual: Low-light cinematic shot of a focused individual writing]
[Text Overlay: {args.hook.upper()}]
[VO]: {args.hook}
[Visual: Close up of a ticking clock]
[VO]: Reading is passive. Implementation is active.
[VO]: Most people use books as a form of productive procrastination.
[VO]: They read to feel like they are progressing while standing still.
[Visual: A person slamming a book shut]
[Text Overlay: STOP CONSUMING]
[VO]: The MindFrame protocol is simple: Read one chapter. Execute one action.
[VO]: Information without execution is just mental clutter.
[Visual: Person working at a clean desk]
[Text Overlay: START BUILDING]
[VO]: High-performers are defined by their output, not their library size.
[VO]: Stop being a collector of ideas. Become an architect of reality.
[Visual: MindFrame logo on black background]
[Text Overlay: JOIN THE 1%]
[VO]: Join the community of those who finish. Link in bio.
""")

if __name__ == "__main__":
    main()
