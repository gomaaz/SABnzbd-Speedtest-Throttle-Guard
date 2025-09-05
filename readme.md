# SABnzbd Auto-Throttle Guard

This repository contains a Bash script that automatically adjusts the download speed limit of your [SABnzbd](https://sabnzbd.org/) instance based on the results of periodic internet speed tests.  
It is designed to run from a cron job (e.g. every hour) and helps avoid saturating your network when bandwidth is low.

---

## ✨ Features

- Runs multiple internet speed tests using [`speedtest-cli`](https://github.com/sivel/speedtest-cli).
- Evaluates all test results against a configurable threshold (default: **300 Mbit/s**).
- If all results are **below the threshold** → sets a speed limit (default: **5 MB/s**) in SABnzbd.  
- If at least one result is **above the threshold** → removes any speed limit.
- Logs actions and test results with timestamps.
- Fully configurable through variables at the top of the script.

---

## ⚙️ How It Works

1. The script calls `speedtest-cli --json` `NUM_TESTS` times.  
2. It parses the reported **download speed** (in bits per second) and converts it to Mbit/s.  
3. If all tests fall below the threshold, the script sends an API call to SABnzbd to apply a configured limit.  
   - Example: `5M` = 5 MB/s = ~40 Mbit/s.  
4. Otherwise, it sends an API call with `0` to disable the limit.  
5. The result of the API call is logged to your log file.

---

## 🛠 Requirements

- Linux system with:
  - `bash`
  - `curl`
  - [`speedtest-cli`](https://github.com/sivel/speedtest-cli) (Python version)  
- A running SABnzbd instance with:
  - API key enabled  
  - Network access from the machine running this script  

---

## 🔧 Configuration

At the top of the script you can set:

```bash
SAB_HOST="172.20.0.3:8080"      # SABnzbd host:port
API_KEY="your_sabnzbd_api_key"  # SABnzbd API key
THRESHOLD_MBIT=300              # Minimum acceptable bandwidth
LIMIT_VALUE="5M"                # Speed limit to set if below threshold
NUM_TESTS=2                     # How many speed tests to run each cycle
SLEEP_BETWEEN=3                 # Delay (seconds) between tests
```

## 🔧 Install

Create cronjob with
```bash
crontab -e
```

Then set the cronjob for e.g. every hour
```bash
0 * * * * /yourlocation/sab-throttle-guard.sh >/dev/null 2>&1
```

##  Example Output
```bash
[2025-09-05 14:00:01] Starting 2 speedtests (speedtest-cli)…
[2025-09-05 14:00:35] Test 1: 248.11 Mbit/s
[2025-09-05 14:01:10] Test 2: 251.34 Mbit/s
[2025-09-05 14:01:11] At least one result < 300 Mbit/s → Set SABnzbd limit to 5MB/s…
[2025-09-05 14:01:11] SABnzbd response: {"status": true}
[2025-09-05 14:01:11] Done.
```
