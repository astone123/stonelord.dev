#!/usr/bin/env bash
#
# One-time CloudFront fixes for stonelord.dev (August 2026 site review):
#
#   1. Custom error responses on BOTH distributions: 403 and 404 from the
#      origin are answered with /404.html and a 404 status, so bad URLs get
#      the styled Not-Found page instead of S3's raw NoSuchKey error.
#   2. A CloudFront Function on the www distribution that 301-redirects
#      www.stonelord.dev -> stonelord.dev, preserving path and query string
#      (code in www-redirect-function.js next to this script).
#
# The CI deploy user can't touch CloudFront config, so run this with admin
# credentials:
#
#   AWS_PROFILE=<admin-profile> ./infra/apply-cloudfront-fixes.sh
#
# Idempotent: re-running skips anything already in place. Run with WAIT=1 to
# also block until both distributions finish deploying (~5-10 min) and then
# run the curl verification checks.
#
# Safe to run before or after the c3-index-redesign PR lands: the styled 404
# only renders once /404.html is actually on the bucket, and until then bad
# URLs just keep showing the raw error.

set -euo pipefail
cd "$(dirname "$0")"

APEX_DOMAIN="stonelord.dev"
WWW_DOMAIN="www.stonelord.dev"
FN_NAME="www-to-apex-redirect"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

ERROR_RESPONSES='{
  "Quantity": 2,
  "Items": [
    { "ErrorCode": 403, "ResponsePagePath": "/404.html", "ResponseCode": "404", "ErrorCachingMinTTL": 60 },
    { "ErrorCode": 404, "ResponsePagePath": "/404.html", "ResponseCode": "404", "ErrorCachingMinTTL": 60 }
  ]
}'

echo "Looking up distributions by alias..."
DISTS=$(aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{Id:Id,Aliases:Aliases.Items}' --output json)
APEX_ID=$(jq -r --arg d "$APEX_DOMAIN" \
  '.[] | select(.Aliases and (.Aliases | index($d))) | .Id' <<<"$DISTS" | head -1)
WWW_ID=$(jq -r --arg d "$WWW_DOMAIN" \
  '.[] | select(.Aliases and (.Aliases | index($d))) | .Id' <<<"$DISTS" | head -1)

if [ -z "$APEX_ID" ] || [ -z "$WWW_ID" ] || [ "$APEX_ID" = "$WWW_ID" ]; then
  echo "Expected two distinct distributions aliased to $APEX_DOMAIN and $WWW_DOMAIN," >&2
  echo "found apex='$APEX_ID' www='$WWW_ID'. Aborting." >&2
  exit 1
fi
echo "  apex ($APEX_DOMAIN): $APEX_ID"
echo "  www  ($WWW_DOMAIN):  $WWW_ID"

echo "Ensuring CloudFront Function $FN_NAME is up to date and published..."
FN_CONFIG='{"Comment":"301 www.stonelord.dev -> stonelord.dev","Runtime":"cloudfront-js-2.0"}'
if aws cloudfront describe-function --name "$FN_NAME" >/dev/null 2>&1; then
  ETAG=$(aws cloudfront describe-function --name "$FN_NAME" --query ETag --output text)
  aws cloudfront update-function --name "$FN_NAME" --if-match "$ETAG" \
    --function-config "$FN_CONFIG" --function-code fileb://www-redirect-function.js >/dev/null
else
  aws cloudfront create-function --name "$FN_NAME" \
    --function-config "$FN_CONFIG" --function-code fileb://www-redirect-function.js >/dev/null
fi
ETAG=$(aws cloudfront describe-function --name "$FN_NAME" --query ETag --output text)
aws cloudfront publish-function --name "$FN_NAME" --if-match "$ETAG" >/dev/null
FN_ARN=$(aws cloudfront describe-function --name "$FN_NAME" --stage LIVE \
  --query 'FunctionSummary.FunctionMetadata.FunctionARN' --output text)
echo "  published: $FN_ARN"

# update_distribution <id> [jq args...] <jq filter>
# get-distribution-config -> apply the jq filter -> update-distribution,
# skipping the update when the filter changes nothing.
update_distribution() {
  local id="$1"; shift
  local tmp etag
  tmp=$(mktemp -d)
  aws cloudfront get-distribution-config --id "$id" >"$tmp/full.json"
  etag=$(jq -r .ETag "$tmp/full.json")
  jq .DistributionConfig "$tmp/full.json" >"$tmp/before.json"
  jq "$@" "$tmp/before.json" >"$tmp/after.json"
  if [ "$(jq -S . "$tmp/before.json")" = "$(jq -S . "$tmp/after.json")" ]; then
    echo "  $id: already configured, skipping"
  else
    aws cloudfront update-distribution --id "$id" --if-match "$etag" \
      --distribution-config "file://$tmp/after.json" >/dev/null
    echo "  $id: update submitted"
  fi
  rm -rf "$tmp"
}

echo "Applying custom error responses to the apex distribution..."
update_distribution "$APEX_ID" --argjson err "$ERROR_RESPONSES" \
  '.CustomErrorResponses = $err'

echo "Applying custom error responses + redirect function to the www distribution..."
update_distribution "$WWW_ID" --argjson err "$ERROR_RESPONSES" --arg arn "$FN_ARN" '
  .CustomErrorResponses = $err
  | .DefaultCacheBehavior.FunctionAssociations = (
      (((.DefaultCacheBehavior.FunctionAssociations.Items // [])
        | map(select(.EventType != "viewer-request")))
       + [{ FunctionARN: $arn, EventType: "viewer-request" }]) as $items
      | { Quantity: ($items | length), Items: $items }
    )
'

echo
echo "Done. CloudFront deploys take ~5-10 minutes."
if [ "${WAIT:-0}" = "1" ]; then
  echo "Waiting for both distributions to deploy..."
  aws cloudfront wait distribution-deployed --id "$APEX_ID"
  aws cloudfront wait distribution-deployed --id "$WWW_ID"
  echo "Deployed. Verifying..."
  echo "--- www redirect (expect 301 + location: https://stonelord.dev/foo?bar=1) ---"
  curl -sI "https://www.stonelord.dev/foo?bar=1" | grep -iE '^HTTP|^location'
  echo "--- bad URL (expect 404; the styled page once /404.html is deployed) ---"
  curl -s -o /dev/null -w '%{http_code}\n' "https://stonelord.dev/definitely-not-a-page"
else
  echo "Re-run with WAIT=1 to block until deployed and run the curl checks."
fi
