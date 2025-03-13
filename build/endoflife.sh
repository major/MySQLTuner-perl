#!/bin/bash

# Check if a product name has been provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <product_name>"
  exit 1
fi

# Product name passed as an argument
produit="$1"

# URL of the API for the specified product
url="https://endoflife.date/api/${produit}.json"

# Perform the HTTP GET request with curl
response=$(curl --silent --fail "$url")

# Check if the request was successful
if [ $? -ne 0 ]; then
  echo "Error: Unable to retrieve information for product '$produit'."
  exit 1
fi

curl --silent --fail "$url" | jq .
# Get the current date
current_date=$(date +%Y-%m-%d)

# Generate a Markdown file with a single table sorted by end of support date
echo -e "# Version Support for $produit\n" > ${produit}_support.md

echo "| Version | End of Support Date | LTS | Status |" >> ${produit}_support.md
echo "|---------|------------------------|-----|--------|" >> ${produit}_support.md
echo "$response" | jq -r --arg current_date "$current_date" '.[] | {cycle, eol, lts} | .status = (if (.eol | type) == "string" and .eol > $current_date then "Supported" elif (.eol | type) == "string" then "Outdated" else "Supported" end) | .lts_status = (if .lts == true then "YES" else "NO" end) | select(.eol != null) | [.] | sort_by(.eol)[] | "| " + .cycle + " | " + (.eol // "N/A") + " | " + .lts_status + " | " + .status + " |"' >> ${produit}_support.md

# Indicate that the Markdown file has been generated
echo "The file ${produit}_support.md has been successfully generated."
