#!/bin/bash
echo "project,session_id,request_id,timestamp,model,input_tokens,output_tokens,cache_creation_tokens,cache_read_tokens,cost_usd"

find ~/.claude/projects -name "*.jsonl" -type f 2>/dev/null | while read f; do
  project=$(dirname "$f" | xargs basename)

  jq -r --arg proj "$project" '
    select(.message.usage) |
    [$proj, .sessionId, .requestId, .timestamp, .message.model,
     .message.usage.input_tokens, .message.usage.output_tokens,
     .message.usage.cache_creation_input_tokens, .message.usage.cache_read_input_tokens,
     0] | @csv
  ' "$f" 2>/dev/null
done
