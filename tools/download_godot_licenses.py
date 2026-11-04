"""Vendor exact Godot 4.7.2 license notices from the official source release.

The Git blob SHA returned by the official GitHub content API is checked against
the downloaded bytes. Build packaging uses these local notices without network.
"""

import hashlib
import json
from pathlib import Path
import urllib.request


TAG = "4.7.2-stable"
DESTINATION = Path(__file__).resolve().parents[1] / "docs" / "licenses"
REPOSITORY = "godotengine/godot"


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "GoldenHour-License-Provenance"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read()


def main():
    DESTINATION.mkdir(parents=True, exist_ok=True)
    records = []
    for filename in ["LICENSE.txt", "COPYRIGHT.txt"]:
        url = f"https://raw.githubusercontent.com/{REPOSITORY}/{TAG}/{filename}"
        metadata_url = f"https://api.github.com/repos/{REPOSITORY}/contents/{filename}?ref={TAG}"
        metadata = json.loads(fetch(metadata_url))
        content = fetch(url)
        blob = b"blob " + str(len(content)).encode("ascii") + b"\0" + content
        actual_blob_sha = hashlib.sha1(blob).hexdigest()
        if actual_blob_sha != metadata["sha"]:
            raise RuntimeError(f"Official source blob did not match for {filename}")
        destination = DESTINATION / f"Godot-{filename}"
        destination.write_bytes(content)
        record = {"file": destination.name, "source": url, "tag": TAG,
                  "git_blob_sha1": actual_blob_sha, "sha256": hashlib.sha256(content).hexdigest()}
        records.append(record)
        print(f"Verified {destination.name}: {record['sha256']}")
    (DESTINATION / "SOURCES.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
