# Elasticsearch Index Exporter (v2)

## 📌 Overview

This tool exports data from Elasticsearch indices to local JSON files using the Scroll API.

It is designed for:

* Very large datasets (millions to tens of millions of documents)
* Reliable full exports (fail-fast, no silent data loss)
* Real-time progress tracking with ETA and speed metrics

Each index is exported into a separate `.json` file in **JSON Lines format (NDJSON)**.

---

## 🚀 Features

* ✅ Full export using Elasticsearch Scroll API
* ✅ Multi-index support
* ✅ Rolling ETA (stable and accurate over time)
* ✅ Progress bar (like `rsync`)
* ✅ Speed calculation (documents per second)
* ✅ Fail-fast error handling (stops on any error)
* ✅ Separate output file per index
* ✅ Automatic scroll cleanup

---

## ⚙️ Requirements

* `bash`
* `curl`
* `jq`
* `bc`

Install dependencies (Rocky / RHEL):

```bash id="dep_install"
dnf install -y curl jq bc
```

---

## ▶️ Usage

1. Edit configuration inside the script:

```bash id="config_example"
ES="https://user:password@host:9200"
OUTPUT_DIR="/mnt/newdisk"
```

2. Run:

```bash id="run_example"
chmod +x export.sh
./export.sh
```

---

## 📂 Output

Each index is exported to:

```id="output_path"
/mnt/newdisk/<index_name>.json
```

Example:

```id="output_example"
/mnt/newdisk/index-name-2022.json
```

---

## 📄 Output Format

Data is stored as **JSON Lines (NDJSON)**:

```json id="json_example"
{"@timestamp":"2022-09-10T23:56:47.869Z","message":"...","env":"env_example"}
{"@timestamp":"2022-09-11T19:33:07.263Z","message":"...","env":"env_example"}
{"@timestamp":"2022-09-12T23:18:37.910Z","message":"...","env":"env_example"}
```

✔ One document per line
✔ Easy to parse (`jq`, `grep`, `awk`)
✔ Easy to re-import to Elasticsearch

---

## 📊 Runtime Output (Progress)

The script displays a real-time progress line:

```id="progress_example"
[##########--------------------]  34% | Batch 23000/68235 | Speed: 18234.22 docs/s | Elapsed: 00h:18m:12s | ETA: 19:02:11
```

### Explanation:

| Field        | Description                     |
| ------------ | ------------------------------- |
| Progress bar | Visual completion indicator     |
| %            | Percentage of processed batches |
| Batch        | Current batch / total batches   |
| Speed        | Documents processed per second  |
| Elapsed      | Time since export started       |
| ETA          | Estimated completion time       |

---

## ⏱️ ETA Calculation

ETA is based on a **rolling average (last N batches)**:

* More stable than simple average
* Becomes accurate after initial batches
* Adapts to changing performance

---

## ❌ Error Handling

If any error occurs (HTTP error, parsing issue, missing data):

```id="error_example"
Error at batch 120 (HTTP 500)
```

👉 The script immediately stops to prevent incomplete or corrupted exports.

---

## 📦 Performance Notes

* Large indices (50M+ docs) can take **hours**
* Disk I/O and network speed affect performance
* Typical speed: **10k–50k docs/sec** (depends on environment)

---

## ⚠️ Important Notes

* Ensure enough disk space before running
* Output files can reach **10–100+ GB per index**
* ETA is less accurate during the first few batches
* Script uses `-k` (insecure SSL) — adjust for production security if needed

---

## 💡 Tips

### Run in background session

```bash id="screen_tip"
screen -S es-export
```

### Monitor disk usage

```bash id="disk_usage"
df -h
```

### Watch file growth

```bash id="watch_files"
watch -n 5 ls -lh /mnt/newdisk
```

---

## 🔧 Possible Improvements

* Gzip compression (`.json.gz`)
* Resume after interruption (checkpoint)
* Parallel exports (multi-index concurrency)
* Throttling to reduce Elasticsearch load
* Direct export to object storage (S3, Swift)

---

## 🧠 Use Cases

* Backup Elasticsearch indices
* Migration between clusters
* Offline log analysis
* Compliance / archiving

---

## 📁 Example Index List

```id="index_list"
index-name-2022
index-name-2023
index-name-2024.*
index-name-2025.*
index-name-2026.*
```

---

## ✅ Summary

This tool provides a **safe, observable, and scalable** way to export large Elasticsearch datasets with:

* Full control
* Real-time visibility
* Production-grade reliability

---
