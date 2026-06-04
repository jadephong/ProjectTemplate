#!/usr/bin/env bash
#
# 用 GitHub App private key 生成 installation access token，供 gh CLI 以 bot 身份操作。
# 与 gh-app-token.ps1 等价（Linux/macOS 原生版，仅依赖 openssl/curl/grep/sed）。
#
# 用法:
#   export GH_TOKEN=$(bash scripts/gh-app-token.sh <app_id> <installation_id> <pem_path>)
#   gh pr comment 12 --repo jadephong/BasePortal --body "hi from bot"
#
set -euo pipefail

app_id="${1:?需要 app_id}"
installation_id="${2:?需要 installation_id}"
pem="${3:?需要 pem 路径}"

if [[ ! -f "$pem" ]]; then
  echo "private key 不存在：$pem。请把对应 GitHub App 的 .pem 放到该路径。" >&2
  exit 1
fi

for bin in openssl curl; do
  command -v "$bin" >/dev/null 2>&1 || { echo "缺少依赖：$bin" >&2; exit 1; }
done

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

now=$(date +%s)
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$((now - 60))" "$((now + 540))" "$app_id" | b64url)
signing_input="${header}.${payload}"
signature=$(printf '%s' "$signing_input" | openssl dgst -sha256 -sign "$pem" -binary | b64url)
jwt="${signing_input}.${signature}"

response=$(curl -s -X POST \
  -H "Authorization: Bearer ${jwt}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "User-Agent: workflow-runner-bot" \
  "https://api.github.com/app/installations/${installation_id}/access_tokens")

# 不依赖 jq，提取 .token
token=$(printf '%s' "$response" \
  | grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -1 \
  | sed -E 's/.*"token"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')

if [[ -z "${token}" || "${token}" == "null" ]]; then
  echo "换取 installation token 失败，GitHub 返回：$response" >&2
  exit 1
fi

printf '%s' "$token"
