#!/bin/bash
# Usage: bulk_generate.sh <subject> <type> <target_total> <per_call_count>
# Loops `npm run generate` until shipped+staged reaches <target_total>.
set -uo pipefail
SUBJECT=$1
TYPE=$2
TARGET=$3
COUNT=$4
cd "$(dirname "$0")"

current() {
  python3 -c "
import json
def count(path):
    try:
        return len(json.load(open(path)))
    except FileNotFoundError:
        return 0
print(count('../../assets/questions/$SUBJECT/$TYPE.json') + count('staging/$SUBJECT-$TYPE.json'))
"
}

MAX_ITERS=200
i=0
while [ "$(current)" -lt "$TARGET" ] && [ $i -lt $MAX_ITERS ]; do
  echo "=== iteration $i, current=$(current), target=$TARGET ==="
  npm run generate -- --subject "$SUBJECT" --type "$TYPE" --count "$COUNT" || echo "  (batch failed, continuing)"
  i=$((i+1))
done
echo "bulk_generate done for $SUBJECT/$TYPE. Final count: $(current)"
