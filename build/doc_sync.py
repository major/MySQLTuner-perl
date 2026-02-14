#!/usr/bin/env python3
import os
import re

PROJECT_ROOT = os.getcwd()
AGENT_DIR = os.path.join(PROJECT_ROOT, '.agent')
README_PATH = os.path.join(AGENT_DIR, 'README.md')

def parse_aff(file_path):
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Extract title (first # header)
        title_match = re.search(r'^#\s+(.*)', content, re.MULTILINE)
        title = title_match.group(1).strip() if title_match else os.path.basename(file_path)
        
        # Extract description from frontmatter
        desc_match = re.search(r'description:\s*(.*)', content)
        description = desc_match.group(1).strip() if desc_match else "No description available."
        
        return title, description
    except Exception as e:
        return os.path.basename(file_path), f"Error parsing: {str(e)}"

def generate_readme():
    categories = {
        'rules': 'Governance & Execution Constraints',
        'skills': 'Specialized Capabilities & Knowledge',
        'workflows': 'Automation & Operational Workflows'
    }
    
    output = ["---"]
    output.append("trigger: always_on")
    output.append("description: Overview of project governance, skills, and workflows")
    output.append("category: governance")
    output.append("---")
    output.append("# .agent - Project Governance & Artificial Intelligence Intelligence\n")
    output.append("This directory contains the project's technical constitution, specialized skills, and operational workflows used by AI agents.\n")
    
    for folder, cat_title in categories.items():
        folder_path = os.path.join(AGENT_DIR, folder)
        if not os.path.exists(folder_path):
            continue
            
        output.append(f"## {cat_title}\n")
        output.append("| File | Description |")
        output.append("| :--- | :--- |")
        
        files = sorted(os.listdir(folder_path))
        for filename in files:
            if not filename.endswith('.md'):
                # Handle skill folders (SKILL.md inside)
                skill_path = os.path.join(folder_path, filename, 'SKILL.md')
                if os.path.exists(skill_path):
                    title, desc = parse_aff(skill_path)
                    output.append(f"| [`{filename}/`](./{folder}/{filename}/SKILL.md) | {desc} |")
                continue
                
            title, desc = parse_aff(os.path.join(folder_path, filename))
            output.append(f"| [`{filename}`](./{folder}/{filename}) | {desc} |")
        
        output.append("\n")
    
    output.append("---\n*Generated automatically by `/doc-sync` on " + os.popen('date').read().strip() + "*")
    
    with open(README_PATH, 'w') as f:
        f.write("\n".join(output))
    
    print(f"Documentation synchronized: {README_PATH}")

if __name__ == "__main__":
    generate_readme()
