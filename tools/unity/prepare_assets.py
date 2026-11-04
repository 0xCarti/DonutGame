"""Prepare Unity material channel data and preserve existing original audio/branding."""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "unity" / "GoldenHour"
ART = PROJECT / "Assets" / "Art"

def main():
    textures = ART / "Textures"
    defs = json.loads((textures / "material_manifest.json").read_text(encoding="utf-8-sig"))
    materials = []
    for name, data in defs.items():
        data = dict(data, name=name)
        roughness = data.get("roughnessMap")
        if roughness:
            source = textures / roughness
            if not source.is_file():
                raise FileNotFoundError(source)
            # URP Lit reads metal from red and smoothness from alpha, in linear space.
            with Image.open(source) as image:
                smoothness = ImageOps.invert(image.convert("L"))
                metal = Image.new("L", image.size, round(data.get("metallic", 0) * 255))
                zero = Image.new("L", image.size, 0)
                packed = Image.merge("RGBA", (metal, zero, zero, smoothness))
                output = f"{name}_metallic_smoothness.png"
                packed.save(textures / output, optimize=True)
                data["metallicSmoothnessMap"] = output
        materials.append(data)
    (textures / "unity_materials.json").write_text(json.dumps({"materials": materials}, indent=2), encoding="utf-8")
    destination = PROJECT / "Assets" / "AudioAndBrand"
    destination.mkdir(parents=True, exist_ok=True)
    names = set()
    for source in (ROOT / "assets" / "audio").rglob("*.wav"):
        if source.name in names:
            raise ValueError(f"Duplicate sound filename: {source.name}")
        names.add(source.name)
        shutil.copy2(source, destination / source.name)
    for source in [ROOT / "assets/fonts/Fredoka-Medium.ttf", ROOT / "assets/fonts/OFL.txt", ROOT / "assets/art/title_keyart.png"]:
        shutil.copy2(source, destination / source.name)
    required = ["Fryer", "Counter", "Tray", "Scoop", "Bag", "Bucket", "Shaker", "ShakerPowdered", "MiniDonut", "Extinguisher", "ServiceBell", "Canopy", "HangingSign", "PendantLamp", "SandwichBoard", "MarketStall", "ParkBench", "FerrisWheel"]
    for prop in required:
        path = ART / "Props" / (prop + ".fbx")
        if not path.is_file() or path.stat().st_size < 1024:
            raise FileNotFoundError(f"Missing authored prop: {path}")
    for name in ("BakerHands", "Customer_Milo"):
        path = ART / "Characters" / (name + ".fbx")
        if not path.is_file() or path.stat().st_size < 1024:
            raise FileNotFoundError(f"Missing character: {path}")
    with Image.open(textures / "oil_flame.png") as flame:
        if flame.mode != "RGBA" or flame.getchannel("A").getextrema()[0] != 0:
            raise ValueError("Fire sprite needs genuine transparent alpha")
    print(f"Prepared {len(materials)} materials; {len(names)} sounds; {len(required)} props; 2 skinned rigs; transparent fire sprite.")

if __name__ == "__main__":
    main()
