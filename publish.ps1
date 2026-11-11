param(
  [string]$Source = "",
  [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$site = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $site

# 本机走代理访问 github.com（Clash 默认端口，可在 git config 里改）
if (-not (git config --local --get http.proxy)) {
  git config --local http.proxy "http://127.0.0.1:7897" | Out-Null
}

if (-not $Source) {
  # 桌面目录被整理过：优先找 02_*/数据处理，找不到再回退旧路径
  $dataDir = $null
  $root = Get-ChildItem "D:\Desktop" -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName "数据处理\光谱与良率分析工作台*.html") } |
    Select-Object -First 1
  if ($root) { $dataDir = Join-Path $root.FullName "数据处理" }
  if (-not $dataDir) { $dataDir = "D:\Desktop\数据处理" }
  $latest = Get-ChildItem (Join-Path $dataDir "光谱与良率分析工作台*.html") -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (-not $latest) { throw "未找到工作台 HTML（$dataDir\光谱与良率分析工作台*.html）" }
  $Source = $latest.FullName
}
if (-not (Test-Path $Source)) { throw "文件不存在：$Source" }

$ver = [System.IO.Path]::GetFileNameWithoutExtension($Source)
$dst = Join-Path $site "index.html"
$old = if (Test-Path $dst) { (Get-FileHash $dst -Algorithm SHA256).Hash } else { "" }
Copy-Item $Source $dst -Force
$new = (Get-FileHash $dst -Algorithm SHA256).Hash
if ($old -eq $new) {
  "index.html 已是最新（$ver）"
} else {
  "已更新 index.html ← $ver（{0:N0} 字节）" -f (Get-Item $dst).Length
}

git add -A
if (-not (git status --porcelain)) { "没有需要提交的改动"; exit 0 }

$msg = if ($Message) { $Message } else { "更新工作台：$ver" }
$msgFile = Join-Path $env:TEMP ("wb-commit-{0}.txt" -f [guid]::NewGuid().ToString("N"))
[System.IO.File]::WriteAllText($msgFile, $msg, (New-Object System.Text.UTF8Encoding($false)))
try { git commit -F $msgFile } finally { Remove-Item $msgFile -ErrorAction SilentlyContinue }
if ($LASTEXITCODE -ne 0) { throw "提交失败" }

$pushed = $false
for ($i = 1; $i -le 4; $i++) {
  git push 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { $pushed = $true; break }
  "推送第 $i 次失败，重试…"
  Start-Sleep -Seconds (6 * $i)
}
if (-not $pushed) { throw "推送失败，检查网络/代理/token（git config --local http.proxy 当前为 $((git config --local --get http.proxy))）" }

"已推送，约 1 分钟后生效：https://wx995.github.io/workbench/"
