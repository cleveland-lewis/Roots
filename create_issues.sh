#!/usr/bin/env bash
# Script to create GitHub labels and issues for build failures.
# Usage: export GITHUB_TOKEN=ghp_xxx; ./create_issues.sh owner repo

OWNER="$1"
REPO="$2"
if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
  echo "Usage: $0 <owner> <repo>" >&2
  exit 1
fi

AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
API="https://api.github.com/repos/$OWNER/$REPO"

# Create labels
create_label() {
  local name="$1";
  local color="$2";
  printf "Creating label %s\n" "$name"
  curl -s -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "{\"name\": \"$name\", \"color\": \"$color\"}" "$API/labels" | jq -r '.message // .name'
}

create_label "bug" "d73a4a"
create_label "build-failure" "5319e7"
create_label "ci" "1d76db"

# Create issue using the markdown file
TITLE=$(sed -n '1p' ISSUES/BUILD-FAILURE-1.md)
BODY=$(sed -n '3,$p' ISSUES/BUILD-FAILURE-1.md | sed '1d')

create_issue() {
  local title="$1";
  local body="$2";
  curl -s -X POST -H "$AUTH_HEADER" -H "Content-Type: application/json" -d "{\"title\": \"$title\", \"body\": \"$body\", \"labels\": [\"bug\", \"build-failure\", \"ci\"] }" "$API/issues" | jq -r '.html_url'
}

create_issue "$TITLE" "$BODY"
