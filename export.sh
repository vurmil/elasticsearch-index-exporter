#!/bin/bash

# ============================
# Elasticsearch config
# ============================
ES="https://elastic:PASSWORD@elasticsearch.domain.com:9200"
SCROLL="5m"
SIZE=1000
OUTPUT_DIR="/mnt/newdisk"

# Index list
INDICES=(
  "index-name-2022"
  "index-name-2023"
  "index-name-2024.01"
  "index-name-2024.02"
  "index-name-2024.03"
  "index-name-2024.04"
  "index-name-2024.05"
  "index-name-2024.06"
  "index-name-2024.07"
  "index-name-2024.08"
  "index-name-2024.09"
  "index-name-2024.10"
  "index-name-2024.11"
  "index-name-2024.12"
  "index-name-2025.01"
  "index-name-2025.02"
  "index-name-2025.03"
  "index-name-2025.04"
  "index-name-2025.05"
  "index-name-2025.06"
  "index-name-2025.07"
  "index-name-2025.08"
  "index-name-2025.09"
  "index-name-2025.10"
  "index-name-2025.11"
  "index-name-2025.12"
  "index-name-2026.01"
  "index-name-2026.02"
  "index-name-2026.03"
)

# ============================
# Function: format seconds
# ============================
format_time() {
  local T=$1
  printf '%02dh:%02dm:%02ds\n' $((T/3600)) $((T%3600/60)) $((T%60))
}

# ============================
# Export function
# ============================
export_index() {
  local INDEX="$1"
  local OUTPUT="$OUTPUT_DIR/$INDEX.json"

  echo "==========================="
  echo "Exporting index: $INDEX"
  echo "Output file: $OUTPUT"

  > "$OUTPUT"

  START_TIME=$(date +%s)

  # Get total docs
  total_docs=$(curl -s -k -u elastic:PASSWORD \
    -H 'Content-Type: application/json' \
    -X GET "$ES/$INDEX/_count" | jq -r '.count')

  if [ -z "$total_docs" ]; then
    echo "Failed to get document count for $INDEX"
    return 1
  fi

  total_batches=$(( (total_docs + SIZE - 1) / SIZE ))
  echo "Total documents: $total_docs"
  echo "Total batches: $total_batches"

  # First batch
  HTTP_CODE=$(curl -s -k -u elastic:PASSWORD \
    -H 'Content-Type: application/json' \
    -X POST "$ES/$INDEX/_search?scroll=$SCROLL&size=$SIZE" \
    -d '{"query":{"match_all":{}}}' \
    -o /tmp/response.json -w "%{http_code}")

  if [ "$HTTP_CODE" != "200" ]; then
    echo "Error fetching first batch (HTTP $HTTP_CODE)"
    cat /tmp/response.json
    return 1
  fi

  scroll_id=$(jq -r '._scroll_id' /tmp/response.json)
  batch_data=$(jq -c '.hits.hits[]._source' /tmp/response.json)

  if [ -z "$batch_data" ] || [ "$batch_data" = "null" ]; then
    echo "No data in first batch!"
    return 1
  fi

  echo "$batch_data" >> "$OUTPUT"
  batch_number=1

  # Loop
  while true; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))

    avg_time_per_batch=$((ELAPSED / batch_number))
    remaining_batches=$((total_batches - batch_number))
    remaining_time=$((avg_time_per_batch * remaining_batches))
    ETA_TS=$((NOW + remaining_time))

    echo "Batch $batch_number / $total_batches"
    echo "Elapsed: $(format_time $ELAPSED) | Remaining: $(format_time $remaining_time) | ETA: $(date -d @$ETA_TS)"

    HTTP_CODE=$(curl -s -k -u elastic:PASSWORD \
      -H 'Content-Type: application/json' \
      -X POST "$ES/_search/scroll" \
      -d "{\"scroll\": \"$SCROLL\", \"scroll_id\": \"$scroll_id\"}" \
      -o /tmp/response.json -w "%{http_code}")

    if [ "$HTTP_CODE" != "200" ]; then
      echo "Error fetching batch $batch_number (HTTP $HTTP_CODE)"
      cat /tmp/response.json
      return 1
    fi

    batch_data=$(jq -c '.hits.hits[]._source' /tmp/response.json)
    scroll_id=$(jq -r '._scroll_id' /tmp/response.json)

    if [ -z "$batch_data" ] || [ "$batch_data" = "null" ]; then
      echo "Scroll finished"
      break
    fi

    echo "$batch_data" >> "$OUTPUT"
    batch_number=$((batch_number + 1))
  done

  END_TIME=$(date +%s)
  TOTAL_TIME=$((END_TIME - START_TIME))

  echo "Export finished for $INDEX"
  echo "Total time: $(format_time $TOTAL_TIME)"

  # Cleanup scroll
  curl -s -k -u elastic:PASSWORD \
    -X DELETE "$ES/_search/scroll" \
    -H 'Content-Type: application/json' \
    -d "{\"scroll_id\": [\"$scroll_id\"]}" >/dev/null

  echo "==========================="
}

# ============================
# Main loop
# ============================
for idx in "${INDICES[@]}"; do
  export_index "$idx" || { echo "Export failed for $idx"; exit 1; }
done

echo "All exports completed"
