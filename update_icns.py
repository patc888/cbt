import os
import subprocess

source_img = "/Users/melichan/.gemini/antigravity/brain/53ddb93d-c3a4-42f9-9e89-9552161720aa/media__1777320089806.png"
iconset_dir = "icon.iconset"

sizes = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024
}

for filename, size in sizes.items():
    filepath = os.path.join(iconset_dir, filename)
    print(f"Generating {filepath} ({size}x{size})")
    subprocess.run(f"sips -z {size} {size} '{source_img}' --out '{filepath}'", shell=True)

print("Running iconutil...")
subprocess.run("iconutil -c icns icon.iconset", shell=True)
print("Done")
