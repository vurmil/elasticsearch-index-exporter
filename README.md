# Elasticsearch Index Exporter

## 📌 Overview

This script exports data from Elasticsearch indices to local JSON files using the Scroll API.

It is designed for:

* Large datasets (millions of documents)
* Reliable full exports (no data loss)
* Progress tracking with ETA (estimated time remaining)

Each index is exported into a separate `.json` file in **JSON Lines format (NDJSON)**.

---

## ⚙️ Requirements

* `bash`
* `curl`
* `jq`

Install `jq` if missing:

```bash
dnf install jq -y
```

---

## 🚀 Features

* ✅ Full index export using Scroll API
* ✅ Handles very large indices (tens of millions of documents)
* ✅ Progress tracking (batch, elapsed time, ETA)
* ✅ Automatic error handling (script stops on failure)
* ✅ Separate output file per index
* ✅ Scroll cleanup after completion

---

## 📂 Output Format

Each index is exported to:

```
/mnt/newdisk/<index_name>.json
```

Example:

```
/mnt/newdisk/index-name-2022.json
```

### Data format: JSON Lines (NDJSON)

Each line in the file is a single document:

```json
{"@timestamp":"2022-09-10T23:56:47.869Z","message":"...","env":"env_name"}
{"@timestamp":"2022-09-11T19:33:07.263Z","message":"...","env":"env_name"}
{"@timestamp":"2022-09-12T23:18:37.910Z","message":"...","env":"env_name"}
```

👉 This format is:

* easy to process with tools like `jq`, `grep`, `awk`
* compatible with re-import to Elasticsearch

---

## 📊 Example Script Output

During execution, the script prints progress:

```
===========================
Exporting index: index-name-2022
Output file: /mnt/newdisk/index-name-2022.json

Total documents: 68234249
Total batches: 68235
```

### Progress updates:

```
Batch 120 / 68235
Elapsed: 00h:05m:30s | Remaining: 05h:22m:10s | ETA: Wed Apr 8 18:42:10
```

Where:

* **Batch** → current progress
* **Elapsed** → time since export started
* **Remaining** → estimated time left
* **ETA** → estimated completion time

---

### Completion message:

```
Scroll finished
Export finished for index-name-2022
Total time: 06h:12m:45s
===========================
```

---

## ❌ Error Handling

If any error occurs (e.g. HTTP error, missing data):

```
Error fetching batch 120 (HTTP 500)
```

👉 The script immediately stops to prevent incomplete exports.

---

## ▶️ Usage

1. Edit configuration inside the script:

```bash
ES="https://user:password@host:9200"
OUTPUT_DIR="/mnt/newdisk"
```

2. Run:

```bash
chmod +x export.sh
./export.sh
```

---

## ⚠️ Notes

* Large indices (e.g. 70M+ documents) may take several hours
* ETA becomes accurate after a few batches
* Ensure enough disk space before running
* Output files can be very large (10–100 GB per index)

---

## 💡 Tips

* Use `screen` or `tmux` for long-running exports
* Monitor disk usage:

  ```bash
  df -h
  ```
* Check file growth:

  ```bash
  watch -n 5 ls -lh /mnt/newdisk
  ```

---

## 🔧 Possible Improvements

* Resume export after interruption
* Parallel index export
* Compression (gzip)
* Direct upload to object storage

---
