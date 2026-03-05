#!/bin/bash

# Navigate to the repository root (where the script is located)
cd "$(dirname "$0")"

# Ensure we are in a git repository
if [ ! -d .git ]; then
    echo "Error: Not a git repository."
    exit 1
fi

# Stage all changes
git add .

# Check if there are any staged changes
if git diff --cached --quiet; then
    echo "No changes to check in."
else
    # Create a timestamp for the commit message
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Commit the changes
    git commit -m "Checkpoint: $TIMESTAMP"
    
    echo "✅ Changes checked in successfully at $TIMESTAMP"
fi

git push origin HEAD
