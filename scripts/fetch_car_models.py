#!/usr/bin/env python3
"""Download the garage car models from Sketchfab into art_sources/car_models/<car_id>/.

Needs a free Sketchfab account's API token (sketchfab.com > Settings > Password & API) in
the environment or in .env as SKETCHFAB_API_TOKEN=... (.env is ignored by git). Every chosen
model is CC Attribution, so the game must credit its author; this script records author,
license, and URL in art_sources/car_models/CREDITS.md. Standard library only.

    .venv/bin/python scripts/fetch_car_models.py [car_id ...]
    .venv/bin/python scripts/fetch_car_models.py --credits   # rebuild CREDITS.md offline
"""

import json
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODEL_DIR = ROOT / "art_sources" / "car_models"
API = "https://api.sketchfab.com/v3/models/"
# Chosen for the generation sold in Uzbekistan, a CC Attribution license, and signs that the
# uploader made the model (models that look like re-uploaded store models were rejected).
MODELS = {
	"matiz": "61be0476f0d64a9d8b37e4cdbc430fff",  # Daewoo-matiz (classic M100/M150)
	"spark": "1a932b980a884ecdbb3dfa66cf74ee43",  # Chevrolet Spark 2013 (M300, Ravon R2)
	"nexia": "7356a1413a384f7f8290ddfbdee11a7f",  # nexia 2 (Uzbek Nexia 2)
	"cobalt": "f91cbef731444f939e263041400216ca",  # Chevrolet Cobalt LTZ 2014
	"gentra": "99f158337e2741ac9af2848675f9128a",  # Gentra
	"malibu": "a155e069dbf84db0b3454ba313d0e79f",  # Chevrolet Malibu 2022
}
ALLOWED_LICENSES = ("CC Attribution", "CC0 Public Domain")


def token():
	value = os.environ.get("SKETCHFAB_API_TOKEN", "")
	env = ROOT / ".env"
	if not value and env.exists():
		for line in env.read_text().splitlines():
			if line.startswith("SKETCHFAB_API_TOKEN="):
				value = line.split("=", 1)[1].strip().strip('"')
	if not value:
		sys.exit("Set SKETCHFAB_API_TOKEN in the environment or in .env")
	return value


def get_json(url, auth=None):
	request = urllib.request.Request(url)
	if auth:
		request.add_header("Authorization", f"Token {auth}")
	with urllib.request.urlopen(request, timeout=60) as response:
		return json.load(response)


def fetch(car_id, uid, auth):
	info = get_json(API + uid)
	license_label = (info.get("license") or {}).get("label", "")
	if license_label not in ALLOWED_LICENSES:
		raise RuntimeError(f"{car_id}: license {license_label!r} is not allowed")
	archive = get_json(API + uid + "/download", auth)["gltf"]["url"]
	target = MODEL_DIR / car_id
	with tempfile.TemporaryDirectory() as temp:
		zip_path = Path(temp) / "model.zip"
		with urllib.request.urlopen(archive, timeout=600) as response, open(zip_path, "wb") as out:
			shutil.copyfileobj(response, out)
		unpacked = Path(temp) / "unpacked"
		with zipfile.ZipFile(zip_path) as bundle:
			for member in bundle.namelist():
				if member.startswith("/") or ".." in Path(member).parts:
					raise RuntimeError(f"{car_id}: unsafe path in archive: {member}")
			bundle.extractall(unpacked)
		if target.exists():
			shutil.rmtree(target)
		shutil.copytree(unpacked, target)
	return credit(car_id)


def credit(car_id):
	"""Credit row from the model's license file, which names the real author (it can differ
	from the uploader)."""
	fields = {}
	for line in (MODEL_DIR / car_id / "license.txt").read_text(errors="replace").splitlines():
		line = line.strip()
		if line.startswith("* ") and ":" in line:
			key, value = line[2:].split(":", 1)
			fields[key.strip()] = value.strip()
	author = fields.get("author", "")
	profile = ""
	if "(" in author and author.endswith(")"):
		author, profile = author[: author.rindex("(")].strip(), author[author.rindex("(") + 1 : -1]
	license_label = fields.get("license type", "").split(" (")[0]
	return (car_id, fields.get("title", car_id), author, profile, license_label,
		fields.get("source", ""))


def write_credits(rows):
	path = MODEL_DIR / "CREDITS.md"
	known = {}
	if path.exists():
		for line in path.read_text().splitlines()[4:]:
			if line.startswith("| "):
				known[line.split("|")[1].strip()] = line
	for row in rows:
		car_id, name, author, profile, license_label, url = row
		known[car_id] = f"| {car_id} | [{name}]({url}) | [{author}]({profile}) | {license_label} |"
	lines = ["# Car Model Credits", "", "| Car | Model | Author | License |", "| --- | --- | --- | --- |"]
	path.write_text("\n".join(lines + [known[key] for key in sorted(known)]) + "\n")


def main():
	if sys.argv[1:] == ["--credits"]:
		write_credits([credit(car_id) for car_id in MODELS if (MODEL_DIR / car_id).is_dir()])
		return
	auth = token()
	MODEL_DIR.mkdir(parents=True, exist_ok=True)
	rows = []
	for car_id in sys.argv[1:] or list(MODELS):
		print(f"Downloading {car_id}...", flush=True)
		rows.append(fetch(car_id, MODELS[car_id], auth))
		print(f"  {rows[-1][1]} by {rows[-1][2]} ({rows[-1][4]})")
	write_credits(rows)


if __name__ == "__main__":
	main()
