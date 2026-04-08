#!/bin/bash

# ============================
# Config
# ============================
ES="https://elastic:PASSWORD@w0vmprlevipdata01.cloud.ochk.pl:9200"
SCROLL="5m"
SIZE=1000
OUTPUT_DIR="/mnt/newdisk"
WINDOW=50   # rolling avg window

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
# Helpers
# ============================
format_time() {
  local T=$1
  printf '%02dh:%02dm:%02ds' $((T/3600)) $((T%3600/60)) $((T%60))
}

# ============================
# Export function
# ============================
export_index() {
  local INDEX="$1"
  local OUTPUT="$OUTPUT_DIR/$INDEX.json"

  echo ""
  echo "==========================="
  echo "Exporting index: $INDEX"
  echo "Output: $OUTPUT"

  > "$OUTPUT"

  START_TIME=$(date +%s)
  LAST_TIME=$START_TIME
  times=()

  # Get total docs
  total_docs=$(curl -s -k -u elastic:PASSWORD \
    -H 'Content-Type: application/json' \
    -X GET "$ES/$INDEX/_count" | jq -r '.count')

  if [ -z "$total_docs" ]; then
    echo "Failed to get document count!"
    return 1
  fi

  total_batches=$(( (total_docs + SIZE - 1) / SIZE ))

  echo "Total docs: $total_docs | Total batches: $total_batches"

  # First request
  HTTP_CODE=$(curl -s -k -u elastic:PASSWORD \
    -H 'Content-Type: application/json' \
    -X POST "$ES/$INDEX/_search?scroll=$SCROLL&size=$SIZE" \
    -d '{"query":{"match_all":{}}}' \
    -o /tmp/response.json -w "%{http_code}")

  if [ "$HTTP_CODE" != "200" ]; then
    echo "Error (HTTP $HTTP_CODE)"
    cat /tmp/response.json
    return 1
  fi

  scroll_id=$(jq -r '._scroll_id' /tmp/response.json)
  batch_data=$(jq -c '.hits.hits[]._source' /tmp/response.json)

  if [ -z "$batch_data" ] || [ "$batch_data" = "null" ]; then
    echo "No data!"
    return 1
  fi

  echo "$batch_data" >> "$OUTPUT"
  batch_number=1

  # ============================
  # Loop
  # ============================
  while true; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))

    # measure batch time
    if [ "$batch_number" -gt 1 ]; then
      batch_time=$((NOW - LAST_TIME))
      times+=($batch_time)

      # rolling window
      if [ "${#times[@]}" -gt "$WINDOW" ]; then
        times=("${times[@]:1}")
      fi
    fi

    LAST_TIME=$NOW

    # avg time
    sum=0
    for t in "${times[@]}"; do
      sum=$((sum + t))
    done

    if [ "${#times[@]}" -gt 0 ]; then
      avg_time_per_batch=$(echo "scale=4; $sum / ${#times[@]}" | bc)
    else
      avg_time_per_batch=0
    fi

    remaining_batches=$((total_batches - batch_number))
    remaining_time=$(echo "$avg_time_per_batch * $remaining_batches" | bc | awk '{print int($1)}')

    ETA_TS=$((NOW + remaining_time))

    percent=$(( batch_number * 100 / total_batches ))
    docs_processed=$((batch_number * SIZE))
    speed=$(echo "scale=2; $docs_processed / ($ELAPSED + 1)" | bc)

    # progress bar
    bar_size=30
    filled=$((percent * bar_size / 100))
    empty=$((bar_size - filled))

    bar=$(printf "%${filled}s" | tr ' ' '#')
    bar="$bar$(printf "%${empty}s" | tr ' ' '-')"

    printf "\r[%s] %3d%% | Batch %d/%d | Speed: %s docs/s | Elapsed: %s | ETA: %s" \
      "$bar" "$percent" "$batch_number" "$total_batches" "$speed" \
      "$(format_time $ELAPSED)" "$(date -d @$ETA_TS '+%H:%M:%S')"

    # next batch
    HTTP_CODE=$(curl -s -k -u elastic:PASSWORD \
      -H 'Content-Type: application/json' \
      -X POST "$ES/_search/scroll" \
      -d "{\"scroll\": \"$SCROLL\", \"scroll_id\": \"$scroll_id\"}" \
      -o /tmp/response.json -w "%{http_code}")

    if [ "$HTTP_CODE" != "200" ]; then
      echo ""
      echo "Error at batch $batch_number (HTTP $HTTP_CODE)"
      cat /tmp/response.json
      return 1
    fi

    batch_data=$(jq -c '.hits.hits[]._source' /tmp/response.json)
    scroll_id=$(jq -r '._scroll_id' /tmp/response.json)

    if [ -z "$batch_data" ] || [ "$batch_data" = "null" ]; then
      break
    fi

    echo "$batch_data" >> "$OUTPUT"
    batch_number=$((batch_number + 1))
  done

  echo ""
  END_TIME=$(date +%s)
  TOTAL_TIME=$((END_TIME - START_TIME))

  echo "Finished $INDEX in $(format_time $TOTAL_TIME)"

  # cleanup
  curl -s -k -u elastic:PASSWORD \
    -X DELETE "$ES/_search/scroll" \
    -H 'Content-Type: application/json' \
    -d "{\"scroll_id\": [\"$scroll_id\"]}" >/dev/null

  echo "==========================="
}

# ============================
# Main
# ============================
for idx in "${INDICES[@]}"; do
  export_index "$idx" || { echo "FAILED: $idx"; exit 1; }
done

echo ""
echo "All exports completed successfully"
