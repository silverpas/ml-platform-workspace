#!/usr/bin/env bash
# Publish the ml-project-template/ folder to its own GitHub template repo.
# Workspace only: this script is not copied into any of the four repos.
#
# Usage (from the workspace root): ./publish-template.sh
set -euo pipefail

TEMPLATE_REPO="https://github.com/silverpas/ml-project-template.git"

# Run from the workspace root, wherever the script is called from.
cd "$(dirname "$0")"

# 1. Only committed work gets published.
if [ -n "$(git status --porcelain)" ]; then
  echo "You have uncommitted changes. Commit them first."
  exit 1
fi

# 2. Only publish from main, never from an experiment branch.
if [ "$(git branch --show-current)" != "main" ]; then
  echo "Switch to main first (git switch main)."
  exit 1
fi

# 3. Copy the folder's history into a temporary branch.
git subtree split --prefix=ml-project-template -b template-export

# 4. Push it as main of the template repo. 5. Delete the temporary branch.
git push "$TEMPLATE_REPO" template-export:main
git branch -D template-export

# 6. Report.
echo "Published ml-project-template ($(git rev-parse --short HEAD)) to $TEMPLATE_REPO"
