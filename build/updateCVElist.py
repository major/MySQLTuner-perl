import requests
import json
import csv
import zipfile
import io
import os
from datetime import datetime

# Range of years to analyze
start_year = 2020
current_year = datetime.now().year
years_to_process = list(range(start_year, current_year + 1))

# Filter on MySQL and MariaDB
# Note: The vendor for MySQL is often "oracle" and for MariaDB "mariadb"
target_products = ["mysql", "mariadb"]
output_file = "mysql_mariadb_cve_full.csv"

def get_cvss_score(cve_data_metrics, version):
    if version == 'V3':
        cvss_metrics_v31 = cve_data_metrics.get('cvssMetricV31', [])
        if cvss_metrics_v31:
            cvss_data = cvss_metrics_v31[0].get('cvssData', {})
            return cvss_data.get('baseScore'), cvss_data.get('baseSeverity')
    elif version == 'V2':
        cvss_metrics_v2 = cve_data_metrics.get('cvssMetricV2', [])
        if cvss_metrics_v2:
            cvss_data = cvss_metrics_v2[0].get('cvssData', {})
            return cvss_data.get('baseScore'), cvss_metrics_v2[0].get('baseSeverity') # baseSeverity is directly here
    return None, None

def extract_affected_versions(node):
    """
    Recursively extracts affected products from configuration nodes.
    Returns a list of dicts with vendor, product, version.
    """
    affected = []
    
    # Handle children (nested logic)
    if 'children' in node:
        for child in node['children']:
            affected.extend(extract_affected_versions(child))
            
    # Handle CPE matches
    if 'cpeMatch' in node:
        for match in node['cpeMatch']:
            if match.get('vulnerable'):
                # In JSON 2.0, the URI is often in 'criteria'
                cpe_uri = match.get('criteria')
                
                if cpe_uri:
                    parts = cpe_uri.split(':')
                    if len(parts) >= 6:
                        vendor = parts[3]
                        product = parts[4]
                        version = parts[5]
                        
                        # If the version is generic (* or -), try to enrich with range info
                        version_str = version
                        
                        ranges = []
                        if match.get('versionStartIncluding'):
                            ranges.append(f">= {match['versionStartIncluding']}")
                        if match.get('versionStartExcluding'):
                            ranges.append(f"> {match['versionStartExcluding']}")
                        if match.get('versionEndIncluding'):
                            ranges.append(f"<= {match['versionEndIncluding']}")
                        if match.get('versionEndExcluding'):
                            ranges.append(f"< {match['versionEndExcluding']}")
                        
                        if ranges and (version == '*' or version == '-'):
                            version_str = " ".join(ranges)
                        
                        if any(p_name in product for p_name in target_products):
                            affected.append({
                                'vendor': vendor,
                                'product': product,
                                'version': version_str
                            })
    return affected

print(f"Starting processing for years: {years_to_process}")

# Initialize CSV file with header
with open(output_file, "w", newline="", encoding="utf-8") as csvfile:
    fieldnames = [
        "cve_id", "published_date", "last_modified", "cvss_v3_score", "cvss_v3_severity",
        "cvss_v2_score", "cvss_v2_severity", "summary", "vendor", "product", "version",
        "references"
    ]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

total_count = 0

for year in years_to_process:
    url = f"https://nvd.nist.gov/feeds/json/cve/2.0/nvdcve-2.0-{year}.json.zip"
    print(f"--- Processing year {year} ---")
    print(f"Downloading from {url}...")
    
    try:
        response = requests.get(url, timeout=60, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'})
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"Error downloading for {year} : {e}")
        continue

    print("Extracting and parsing JSON...")
    try:
        with zipfile.ZipFile(io.BytesIO(response.content)) as z:
            json_filename = [name for name in z.namelist() if name.endswith('.json')][0]
            with z.open(json_filename) as f:
                data = json.load(f)
    except Exception as e:
        print(f"Error extracting or parsing JSON for {year} : {e}")
        continue

    cve_items = data.get('vulnerabilities', [])
    print(f"Analyzing {len(cve_items)} CVE entries for {year}...")

    count_year = 0
    with open(output_file, "a", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        # No writeheader() here because it's already done
        
        for vuln_entry in cve_items:
            cve = vuln_entry.get('cve', {})
            cve_id = cve.get('id')
            
            published_date = cve.get('published')
            last_modified = cve.get('lastModified')
            
            description_data = cve.get('descriptions', [])
            summary = description_data[0].get('value') if description_data else ""
            
            references_data = cve.get('references', [])
            references = "; ".join([ref.get('url') for ref in references_data])

            v3_score, v3_severity = get_cvss_score(cve.get('metrics', {}), 'V3')
            v2_score, v2_severity = get_cvss_score(cve.get('metrics', {}), 'V2')

            # Analyze configurations to find products
            configurations = cve.get('configurations', {})
            if isinstance(configurations, list) and configurations:
                configurations = configurations[0]
            
            nodes = configurations.get('nodes', [])
            
            affected_products = []
            for node in nodes:
                affected_products.extend(extract_affected_versions(node))
            
            # Deduplication
            seen = set()
            for prod in affected_products:
                key = (prod['vendor'], prod['product'], prod['version'])
                if key in seen:
                    continue
                seen.add(key)
                
                row = {
                    "cve_id": cve_id,
                    "published_date": published_date,
                    "last_modified": last_modified,
                    "cvss_v3_score": v3_score,
                    "cvss_v3_severity": v3_severity,
                    "cvss_v2_score": v2_score,
                    "cvss_v2_severity": v2_severity,
                    "summary": summary,
                    "vendor": prod['vendor'],
                    "product": prod['product'],
                    "version": prod['version'],
                    "references": references
                }
                writer.writerow(row)
                count_year += 1
    
    print(f"Added {count_year} vulnerabilities for {year}.")
    total_count += count_year

print(f"Done. Total: {total_count} vulnerabilities exported to {output_file}")
exit(0)