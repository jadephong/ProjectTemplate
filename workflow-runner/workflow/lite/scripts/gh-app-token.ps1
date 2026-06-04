<#
.SYNOPSIS
  用 GitHub App 的 private key 生成 installation access token，供 gh CLI 以 bot 身份操作。

.DESCRIPTION
  流程：private key 签名 RS256 JWT → 用 JWT 调 /app/installations/<id>/access_tokens 换 token。
  把输出的 token 设给 $env:GH_TOKEN，后续 gh 命令即以该 App（bot）身份执行，
  评论/PR 会显示为 "<app-name>[bot]"。

.PARAMETER AppId
  GitHub App ID（数字）。

.PARAMETER InstallationId
  该 App 在目标仓库/组织的 Installation ID。

.PARAMETER PemPath
  App private key（.pem）文件路径。

.EXAMPLE
  $env:GH_TOKEN = & scripts/gh-app-token.ps1 -AppId 3954083 -InstallationId 137794452 -PemPath .secrets/jp-developer-bot.pem
  gh pr comment 12 --repo jadephong/BasePortal --body "hi from bot"

.NOTES
  需要 PowerShell 7+（依赖 .NET 的 RSA.ImportFromPem）。Windows PowerShell 5.1 不支持，请用 pwsh 运行。
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$AppId,
  [Parameter(Mandatory = $true)][string]$InstallationId,
  [Parameter(Mandatory = $true)][string]$PemPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $PemPath)) {
  Write-Error "private key 不存在：$PemPath。请把对应 GitHub App 的 .pem 放到该路径。"
  exit 1
}

$rsa = [System.Security.Cryptography.RSA]::Create()
if (-not ($rsa | Get-Member -Name ImportFromPem -MemberType Method)) {
  Write-Error "当前 PowerShell（$($PSVersionTable.PSVersion)）不支持 RSA.ImportFromPem，请用 PowerShell 7+ (pwsh) 运行本脚本。"
  exit 1
}

function ConvertTo-Base64Url([byte[]]$bytes) {
  [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

try {
  $rsa.ImportFromPem((Get-Content $PemPath -Raw))

  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $header  = @{ alg = 'RS256'; typ = 'JWT' } | ConvertTo-Json -Compress
  $payload = @{ iat = $now - 60; exp = $now + 540; iss = $AppId } | ConvertTo-Json -Compress

  $hB64 = ConvertTo-Base64Url([Text.Encoding]::UTF8.GetBytes($header))
  $pB64 = ConvertTo-Base64Url([Text.Encoding]::UTF8.GetBytes($payload))
  $signingInput = "$hB64.$pB64"

  $sig = $rsa.SignData(
    [Text.Encoding]::UTF8.GetBytes($signingInput),
    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
    [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
  )
  $jwt = "$signingInput.$(ConvertTo-Base64Url($sig))"

  $resp = Invoke-RestMethod -Method Post `
    -Uri "https://api.github.com/app/installations/$InstallationId/access_tokens" `
    -Headers @{
      Authorization = "Bearer $jwt"
      Accept        = 'application/vnd.github+json'
      'User-Agent'  = 'workflow-runner-bot'
      'X-GitHub-Api-Version' = '2022-11-28'
    }

  # 仅把 token 打到 stdout，供调用方赋给 $env:GH_TOKEN
  Write-Output $resp.token
}
finally {
  $rsa.Dispose()
}
