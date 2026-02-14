#!/usr/bin/env bash
# styrene-tools statusline for Claude Code
# Shows: git branch | model | context % | MCP servers | cost
#
# Install: add to your Claude Code settings (.claude/settings.json or ~/.claude/settings.json):
#   {
#     "statusLine": {
#       "type": "command",
#       "command": "<path-to-plugin>/statusline/statusline.sh"
#     }
#   }

input=$(cat)

# Parse JSON fields
model=$(echo "$input" | jq -r '.model.display_name // "?"')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // "."')

# Git branch (fast — no network)
branch=$(git -C "$project_dir" branch --show-current 2>/dev/null || true)

# MCP server count — check both user and project configs
mcp_count=0
for f in ~/.claude/mcp.json "${project_dir}/.mcp.json"; do
    if [[ -f "$f" ]]; then
        n=$(jq '.mcpServers | length' "$f" 2>/dev/null || echo 0)
        mcp_count=$((mcp_count + n))
    fi
done

# Build output
parts=()

[[ -n "${branch:-}" ]] && parts+=("$branch")
parts+=("$model")
parts+=("ctx:${ctx_pct}%")
[[ "$mcp_count" -gt 0 ]] && parts+=("mcp:${mcp_count}")

cost_fmt=$(printf '%.2f' "$cost" 2>/dev/null || echo "0.00")
[[ "$cost_fmt" != "0.00" ]] && parts+=("\$${cost_fmt}")

# Join with separator
result=""
for i in "${!parts[@]}"; do
    [[ $i -gt 0 ]] && result+=" | "
    result+="${parts[$i]}"
done
echo "$result"
