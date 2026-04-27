import os
import subprocess

source_img = "/Users/melichan/.gemini/antigravity/brain/53ddb93d-c3a4-42f9-9e89-9552161720aa/media__1777320089806.png"

images_to_replace = [
    "CBT/Assets.xcassets/AppIcon-Stealth.appiconset/AppIcon-Stealth-167.png",
    "CBT/Assets.xcassets/AppIcon-Stealth.appiconset/AppIcon-Stealth@3x.png",
    "CBT/Assets.xcassets/AppIcon-Stealth.appiconset/AppIcon-Stealth@2x.png",
    "CBT/Assets.xcassets/AppIcon-Stealth.appiconset/AppIcon.png",
    "CBT/Assets.xcassets/AppIcon-Stealth.appiconset/AppIcon-Stealth.png",
    "CBT/Assets.xcassets/AppIcon-Stealth.appiconset/AppIcon-Stealth-152.png",
    "CBT/Assets.xcassets/AppIcon 2.appiconset/chores_CBT_icon_2026.001 1.png",
    "CBT/Assets.xcassets/AppIcon 2.appiconset/chores_CBT_icon_2026.001 11.png",
    "CBT/Assets.xcassets/AppIcon 2.appiconset/AppIcon.png",
    "CBT/Assets.xcassets/AppIcon 2.appiconset/CBT_icon.png",
    "CBT/Assets.xcassets/AppIcon 2.appiconset/chores_CBT_icon_2026.001.png",
    "CBT/Assets.xcassets/AppIcon-Feather.appiconset/AppIcon-Feather-167.png",
    "CBT/Assets.xcassets/AppIcon-Feather.appiconset/AppIcon-Feather.png",
    "CBT/Assets.xcassets/AppIcon-Feather.appiconset/AppIcon-Feather@2x.png",
    "CBT/Assets.xcassets/AppIcon-Feather.appiconset/AppIcon-Feather@3x.png",
    "CBT/Assets.xcassets/AppIcon-Feather.appiconset/AppIcon.png",
    "CBT/Assets.xcassets/AppIcon-Feather.appiconset/AppIcon-Feather-152.png",
    "CBT/Assets.xcassets/AppIconFeatherPreview.imageset/AppIcon-Feather@2x.png",
    "CBT/Assets.xcassets/AppIconFeatherPreview.imageset/AppIcon-Feather@3x.png",
    "CBT/Assets.xcassets/AppIconFeatherPreview.imageset/AppIconFeatherPreview.png",
    "CBT/Assets.xcassets/SubscriptionIcon.imageset/SubscriptionIcon.png",
    "CBT/Assets.xcassets/AppIcon.appiconset/chores_CBT_icon_2026.001 1.png",
    "CBT/Assets.xcassets/AppIcon.appiconset/chores_CBT_icon_2026.001 11.png",
    "CBT/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    "CBT/Assets.xcassets/AppIcon.appiconset/CBT_icon.png",
    "CBT/Assets.xcassets/AppIcon.appiconset/chores_CBT_icon_2026.001.png",
    "CBT/Assets.xcassets/AppIconStealthPreview.imageset/AppIcon-Stealth@3x.png",
    "CBT/Assets.xcassets/AppIconStealthPreview.imageset/AppIcon-Stealth@2x.png",
    "CBT/Assets.xcassets/AppIconStealthPreview.imageset/AppIconStealthPreview.png",
    "CBT/Assets.xcassets/AppBrandingIcon.imageset/AppBrandingIcon.png",
    "CBT/Assets.xcassets/AppIcon2Preview.imageset/AppIcon2Preview.png",
    "CBT/Assets.xcassets/AppIcon2Preview.imageset/CBT_icon.png"
]

for img_path in images_to_replace:
    if os.path.exists(img_path):
        # Get dimensions of existing image
        cmd = f"sips -g pixelWidth -g pixelHeight '{img_path}'"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        width = None
        height = None
        for line in result.stdout.split('\n'):
            if 'pixelWidth:' in line:
                width = line.split(':')[1].strip()
            if 'pixelHeight:' in line:
                height = line.split(':')[1].strip()
        
        if width and height:
            print(f"Replacing {img_path} ({width}x{height})")
            # Create a copy of the new image resized to match the old one
            subprocess.run(f"sips -z {height} {width} '{source_img}' --out '{img_path}'", shell=True)
        else:
            print(f"Could not read dimensions for {img_path}")

print("Done")
