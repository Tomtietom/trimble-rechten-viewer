#!/bin/bash
# deploy.sh — bump versie, commit + push. Breekt Trimble Connect iframe cache.
#
# Gebruik:
#   ./deploy.sh "Commit bericht hier"
#
# Wat het doet:
#   1. Timestamp (YYYYMMDDHHmm) in manifest.json injecteren als ?v= query
#   2. Alle wijzigingen committen met meegegeven bericht
#   3. Git push
#
# Na ~1-3 min serveert GitHub Pages de nieuwe versie. Trimble Connect
# ziet een nieuwe URL (?v=202604201547) dus cached niet de oude versie.

set -e
cd "$(dirname "$0")"

MSG="${1:-update}"
V=$(date +%Y%m%d%H%M)

# Update URL in manifest.json: https://tomtietom.github.io/tc-viewer/?v=VERSIE
# Werkt voor: geen query, bestaande ?v=..., bestaande andere query
python3 -c "
import json
with open('manifest.json','r') as f: m = json.load(f)
base = m['url'].split('?')[0]
m['url'] = base + '?v=$V'
with open('manifest.json','w') as f: json.dump(m, f, indent=2, ensure_ascii=False); f.write('\n')
print('manifest.json URL:', m['url'])
"

git add -A
git commit -m "$MSG

Bump versie: $V
"
git push

echo ""
echo "✓ Gedeployed als versie $V"
echo "  Manifest: https://tomtietom.github.io/tc-viewer/manifest.json"
echo "  Viewer:   https://tomtietom.github.io/tc-viewer/?v=$V"
echo ""
echo "Wacht 1-3 min op GitHub Pages rebuild, dan herlaad Trimble Connect"
echo "(complete tab sluiten & opnieuw openen, geen gewone refresh)."
