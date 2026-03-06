import os
import re

files_with_secondary = [
    "/Users/melichan/dev/CBT/CBT/Views/ThoughtRecords/ThoughtRecordListView.swift",
    "/Users/melichan/dev/CBT/CBT/Views/Timeline/TimelineView.swift",
    "/Users/melichan/dev/CBT/CBT/Views/Education/CBTResearchView.swift",
    "/Users/melichan/dev/CBT/CBT/Views/Insights/InsightsView.swift"
]

for filepath in files_with_secondary:
    if not os.path.exists(filepath):
        continue
        
    with open(filepath, "r") as f:
        content = f.read()

    # Check if ThemeManager is in the environment
    if "themeManager" not in content and "@Environment" in content:
        # Add the environment
        content = re.sub(
            r'(@Environment[^\n]+\n)',
            r'\1    @Environment(ThemeManager.self) private var themeManager\n',
            content,
            count=1
        )
    
    # Replace Theme.secondaryColor
    content = content.replace("Theme.secondaryColor", "themeManager.secondaryColor")
    
    with open(filepath, "w") as f:
        f.write(content)
    print(f"Updated {filepath}")
