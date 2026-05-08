#!/usr/bin/env bash
set -e

QUERY="$1"
PROXY="socks5://127.0.0.1:1080"

echo "🔎 Smart YouTube Search: $QUERY"
echo "-----------------------------------"

SEARCH_URL="https://www.youtube.com/results?search_query=$(printf '%s' "$QUERY" | sed 's/ /+/g')"

HTML=$(curl -s \
  --proxy "$PROXY" \
  -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
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

yt-dlp \
  --proxy "$PROXY" \
  --skip-download \
  --js-runtimes "node:$(which node)" \
  --print "TITLE: %(title)s" \
  --print "CHANNEL: %(channel)s" \
  --print "VIEWS: %(view_count)s" \
  --print "DURATION: %(duration_string)s" \
  --print "UPLOAD_DATE: %(upload_date)s" \
  --print "URL: %(webpage_url)s" \
  "$URL" 2>/dev/null || true

echo "-----------------------------------"

sleep 2

done

echo "✅ Smart search completed"
