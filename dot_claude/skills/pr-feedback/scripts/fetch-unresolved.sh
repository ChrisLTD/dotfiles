#!/usr/bin/env bash
# Fetch unresolved review threads for a PR as JSON.
#
# Usage:
#   fetch-unresolved.sh [PR_NUMBER]
#
# With no argument it resolves the PR from the current branch.
# Output: a JSON array on stdout, one object per UNRESOLVED review thread:
#   { threadId, path, line, isOutdated, url, comments: [ { author, body, createdAt, diffHunk } ] }
#
# Requires: gh (authenticated), jq.
set -euo pipefail

for bin in gh jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "error: '$bin' not found on PATH" >&2; exit 1; }
done

# Resolve owner/repo from the current repo.
read -r OWNER REPO < <(gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"')

# Resolve PR number: explicit arg, else from current branch.
PR="${1:-}"
if [[ -z "$PR" ]]; then
  PR="$(gh pr view --json number --jq .number 2>/dev/null || true)"
fi
if [[ -z "$PR" ]]; then
  echo "error: no PR number given and none found for the current branch" >&2
  exit 1
fi

read -r -d '' QUERY <<'GRAPHQL' || true
query($owner:String!, $repo:String!, $pr:Int!, $endCursor:String) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$pr) {
      reviewThreads(first:100, after:$endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first:100) {
            nodes {
              databaseId
              author { login }
              body
              url
              createdAt
              diffHunk
            }
          }
        }
      }
    }
  }
}
GRAPHQL

# --paginate walks reviewThreads.pageInfo automatically. Merge all pages, keep
# only unresolved threads, and flatten to the shape documented above.
gh api graphql --paginate \
  -f query="$QUERY" \
  -F owner="$OWNER" -F repo="$REPO" -F pr="$PR" \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]' \
| jq -s '
  map(select(.isResolved == false))
  | map({
      threadId: .id,
      path: .path,
      line: .line,
      isOutdated: .isOutdated,
      url: (.comments.nodes[0].url // null),
      replyToId: (.comments.nodes[0].databaseId // null),
      comments: [ .comments.nodes[] | {
        author: .author.login,
        body: .body,
        createdAt: .createdAt,
        diffHunk: .diffHunk
      } ]
    })
'
