#!/usr/bin/env bash
set -euo pipefail

# Create a private Git repo on GitHub and push current project.
# Usage:
#   export GITHUB_USER="your-username"
#   export GITHUB_TOKEN="ghp_..." # with repo scope
#   export REPO_NAME="SimpleClip"
#   ./scripts/create_private_repo.sh
#
# If the repo already exists remotely, set REMOTE_URL to skip creation:
#   export REMOTE_URL="https://github.com/$GITHUB_USER/$REPO_NAME.git"
#   ./scripts/create_private_repo.sh

REPO_NAME="${REPO_NAME:-SimpleClip}"
GITHUB_USER="${GITHUB_USER:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REMOTE_URL="${REMOTE_URL:-}"

function ensure_git_initialized() {
  if [ ! -d ".git" ]; then
    git init
  fi
  git add -A
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    git commit -m "Initial import: ${REPO_NAME}"
  else
    # create a commit only if there are staged changes
    if ! git diff --cached --quiet; then
      git commit -m "Prepare push"
    fi
  fi
  git branch -M main || true
}

function create_remote_repo() {
  if [ -n "${REMOTE_URL}" ]; then
    echo "Using existing remote: ${REMOTE_URL}"
    return 0
  fi
  if [ -z "${GITHUB_USER}" ] || [ -z "${GITHUB_TOKEN}" ]; then
    echo "ERROR: GITHUB_USER and GITHUB_TOKEN must be set to create repo"
    exit 1
  fi
  echo "Creating private repo ${REPO_NAME} on GitHub..."
  curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/user/repos \
    -d "{\"name\":\"${REPO_NAME}\",\"private\":true,\"auto_init\":false}" \
    >/dev/null
  REMOTE_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
}

function setup_remote_and_push() {
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "${REMOTE_URL}"
  else
    git remote add origin "${REMOTE_URL}"
  fi
  echo "Pushing to ${REMOTE_URL}..."
  git push -u origin main
}

ensure_git_initialized
create_remote_repo
setup_remote_and_push

echo "Done. Repo: ${REMOTE_URL}"
