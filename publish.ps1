param(
  [string]$Source = "",
  [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$site = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $site

if (-not $Source) {
  $latest = Get-ChildItem "D:\Desktop\数据处理\光谱与良率分析工作台*.html" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (-not $latest) { throw "未找到工作台 HTML（D:\Desktop\数据处理\光谱与良率分析工作台*.html）" }
  $Source = $latest.FullName
}

if (-not (Test-Path $Source)) { throw "文件不存在：$Source" }

$ver = [System.IO.Path]::GetFileNameWithoutExtension($Source)
Copy-Item $Source (Join-Path $site "index.html") -Force
"已更新 index.html ← $ver（{0:N0} 字节）" -f (Get-Item (Join-Path $site "index.html")).Length

git add -A
$msg = if ($Message) { $Message } else { "更新工作台：$ver" }
git commit -m $msg
if ($LASTEXITCODE -ne 0) { "没有需要提交的改动" }

git push
"已推送。约 1 分钟后生效：https://995996-tech.github.io/workbench/"
