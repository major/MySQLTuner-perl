import os
import shutil
import glob

SOURCE_DIR = '../MySQLTuner-perl'
TARGET_DIR = './public/docs'
RELEASES_TARGET = os.path.join(TARGET_DIR, 'releases')

def sync():
    if not os.path.exists(TARGET_DIR):
        os.makedirs(TARGET_DIR)
    if not os.path.exists(RELEASES_TARGET):
        os.makedirs(RELEASES_TARGET)

    # Core files
    files_to_sync = {
        'README.md': 'overview.md',
        'INTERNALS.md': 'internals.md',
        'USAGE.md': 'usage.md',
        'CONTRIBUTING.md': 'contributing.md',
        'mariadb_support.md': 'mariadb_support.md',
        'mysql_support.md': 'mysql_support.md'
    }

    for src_name, dest_name in files_to_sync.items():
        src_path = os.path.join(SOURCE_DIR, src_name)
        if os.path.exists(src_path):
            shutil.copy(src_path, os.path.join(TARGET_DIR, dest_name))
            print(f"Synced {src_name}")

    # Release notes
    release_files = glob.glob(os.path.join(SOURCE_DIR, 'releases', 'v*.md'))
    release_list = []
    for rel_file in release_files:
        basename = os.path.basename(rel_file)
        shutil.copy(rel_file, RELEASES_TARGET)
        release_list.append(basename)
        print(f"Synced release {basename}")

    # Generate Release Index
    release_list.sort(reverse=True)
    with open(os.path.join(RELEASES_TARGET, 'index.md'), 'w') as f:
        f.write("# Release Notes Archive\n\n")
        f.write("Stay up to date with the latest improvements and fixes in MySQLTuner.\n\n")
        for rel in release_list:
            v = rel.replace('.md', '')
            f.write(f"- [{v}](#/docs/releases/{rel})\n")

    # Extract FAQ from README
    readme_path = os.path.join(SOURCE_DIR, 'README.md')
    if os.path.exists(readme_path):
        with open(readme_path, 'r') as f:
            lines = f.readlines()
        
        faq_lines = []
        is_faq = False
        for i, line in enumerate(lines):
            # Check for "FAQ" followed by a underline
            if "FAQ" in line and i + 1 < len(lines) and ("--" in lines[i+1] or "==" in lines[i+1]):
                is_faq = True
                continue
            
            if is_faq:
                if "MySQLTuner and Vagrant" in line or "Contributions welcome" in line:
                    is_faq = False
                    break
                faq_lines.append(line)
        
        if faq_lines:
            with open(os.path.join(TARGET_DIR, 'faq.md'), 'w') as f:
                f.write("# Frequently Asked Questions\n\n")
                f.writelines(faq_lines)
            print("Extracted FAQ")

if __name__ == "__main__":
    sync()
