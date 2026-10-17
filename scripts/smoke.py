#!/usr/bin/env python3
"""Check the running central service without printing response bodies."""
import json
from pathlib import Path
import re
import time
import urllib.request

project = Path(__file__).resolve().parents[1].name
endpoint = {"prometheus": "http://127.0.0.1:9090/-/ready",
            "loki": "http://127.0.0.1:3100/ready",
            "grafana": "http://127.0.0.1:3000/api/health"}[project]
for attempt in range(24):
    try:
        with urllib.request.urlopen(endpoint, timeout=5) as response:
            body = response.read(4096)
            if response.status == 200 and (project != "grafana" or json.loads(body).get("database") == "ok"):
                if project == "prometheus":
                    with urllib.request.urlopen("http://127.0.0.1:9090/api/v1/status/config", timeout=5) as config_response:
                        config = json.load(config_response)["data"]["yaml"]
                    if not re.search(r"out_of_order_time_window: (26h|1d2h)\s", config):
                        raise ValueError("Expected 26h delayed-sample window")
                    with urllib.request.urlopen("http://127.0.0.1:9090/api/v1/status/flags", timeout=5) as flags_response:
                        flags = json.load(flags_response)["data"]
                    if flags["storage.tsdb.retention.time"] != "15d":
                        raise ValueError("Expected 15d retention")
                print(project + " readiness and configured storage policy verified")
                break
    except (OSError, ValueError):
        pass
    time.sleep(5)
else:
    raise SystemExit(project + " readiness failed")
