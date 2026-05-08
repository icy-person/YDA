#!/usr/bin/env bash
set -euo pipefail

QUERY="${1:-}"
PROXY="socks5://127.0.0.1:1080"

if [ -z "$QUERY" ]; then
  echo "Usage: $0 \"search query\""
  exit 1
fi

echo "🔎 Smart YouTube Search: $QUERY"
echo "-----------------------------------"

ENCODED_QUERY=$(printf '%s' "$QUERY" | sed 's/ /+/g')
SEARCH_URL="https://www.youtube.com/results?search_query=${ENCODED_QUERY}"

HTML=$(curl -sL \
  --proxy "$PROXY" \
  -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36" \
  -H "Accept-Language: en-US,en;q=0.9" \
  -H "Referer: https://www.youtube.com/" \
  "$SEARCH_URL")

IDS=$(echo "$HTML" \
  | grep -oE '"videoId":"[a-zA-Z0-9_-]{11}"' \
  | cut -d'"' -f4 \
  | sort -u \
  | head -n 8)

if [ -z "$IDS" ]; then
  echo "❌ No results found"
  exit 0
fi

echo "🎬 Found video IDs:"
echo "$IDS"
echo "-----------------------------------"

for ID in $IDS; do
  URL="https://www.youtube.com/watch?v=$ID"
  echo "📺 Trying: $URL"

  set +e
  OUT=$(yt-dlp \
    --proxy "$PROXY" \
    --skip-download \
    --js-runtimes "node:$(which node)" \
    --print "{ \"id\": \"%(id)s\", \"title\": %(title)j, \"channel\": %(channel)j, \"duration\": %(duration_string)j, \"view_count\": %(view_count)j, \"upload_date\": %(upload_date)j, \"description\": %(description)j, \"thumbnail\": %(thumbnail)j, \"url\": %(webpage_url)j }" \
    "$URL" 2>&1)
  STATUS=$?
  set -e

  if [ $STATUS -eq 0 ]; then
    echo "$OUT"
  else
    if echo "$OUT" | grep -qiE "not a bot|captcha|confirm your age|sign in"; then
      echo "{ \"id\": \"$ID\", \"url\": \"$URL\", \"error\": \"youtube_bot_check_or_auth_required\" }"
    else
      echo "{ \"id\": \"$ID\", \"url\": \"$URL\", \"error\": \"metadata_fetch_failed\" }"
    fi
  fi

  echo "-----------------------------------"
  sleep 2
done

echo "✅ Smart search completed"
