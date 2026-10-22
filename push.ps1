#Requires -Version 5.1
<#
    push.ps1  —  一键把你的代码提交并上传到 GitHub

    用法：
        .\push.ps1                       # 自动生成提交说明
        .\push.ps1 "day003: 合并区间"     # 自己指定说明
        .\push.ps1 -NoPush               # 只提交，不上传（本地存档）

    它会做三件事：git add 全部改动 -> git commit -> git push
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Message,

    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
Set-Location $root

function Invoke-Git {
    param([string[]]$ArgumentList)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git @ArgumentList 2>&1
        $code = $LASTEXITCODE
        $text = (($out | ForEach-Object { "$_" }) -join "`n").Trim()
        return [pscustomobject]@{ Code = $code; Out = $text }
    } finally {
        $ErrorActionPreference = $prev
    }
}

# ---------- 前置检查 ----------
if (-not (Test-Path (Join-Path $root '.git'))) {
    Write-Host "这不是一个 git 仓库：$root" -ForegroundColor Red
    exit 1
}

$remote = Invoke-Git @('remote','get-url','origin')
if ($remote.Code -ne 0) {
    Write-Host '没有配置远端 origin，先运行 git remote add origin <地址>' -ForegroundColor Red
    exit 1
}
$repoUrl = $remote.Out -replace '\.git$',''

# ---------- 1. 暂存所有改动 ----------
$add = Invoke-Git @('add','-A')
if ($add.Code -ne 0) {
    Write-Host "git add 失败：$($add.Out)" -ForegroundColor Red
    exit 1
}

$status = Invoke-Git @('status','--porcelain')
if (-not $status.Out) {
    Write-Host '没有检测到任何改动，无需上传。' -ForegroundColor Yellow
    Write-Host '（代码要放在这个目录里才会被 git 跟踪：' -NoNewline
    Write-Host $root -NoNewline -ForegroundColor White
    Write-Host '）'
    exit 0
}

$changed = @($status.Out -split "`n" | Where-Object { $_.Trim() })
Write-Host ("检测到 {0} 处改动：" -f $changed.Count) -ForegroundColor Cyan
$changed | ForEach-Object { Write-Host ("  " + $_.Trim()) }

# ---------- 2. 生成提交说明 ----------
if (-not $Message -or $Message.Trim() -eq '') {
    # 从改动里找 dayNNN，优先用它当说明
    $dayHit = [regex]::Matches(($changed -join ' '), 'day(\d{3})') |
              ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Descending | Select-Object -First 1
    if ($dayHit) {
        $Message = ('day{0:D3}: 更新 {1} 个文件' -f $dayHit, $changed.Count)
    } else {
        $Message = ('update: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    }
}

# ---------- 3. 提交 ----------
$commit = Invoke-Git @('commit','-m',$Message)
if ($commit.Code -ne 0) {
    Write-Host "提交失败：$($commit.Out)" -ForegroundColor Red
    exit 1
}
$hash = (Invoke-Git @('rev-parse','--short','HEAD')).Out
Write-Host ''
Write-Host ("已提交 [{0}] {1}" -f $hash, $Message) -ForegroundColor Green

if ($NoPush) {
    Write-Host '已按 -NoPush 跳过上传。' -ForegroundColor Yellow
    exit 0
}

# ---------- 4. 上传 ----------
Write-Host '正在上传到 GitHub ...' -ForegroundColor Cyan
$push = Invoke-Git @('-c','http.schannelCheckRevoke=false','push')
if ($push.Code -ne 0) {
    Write-Host ''
    Write-Host '上传失败。排查顺序：' -ForegroundColor Red
    Write-Host '  1) Watt Toolkit(Steam++) 是否在运行？关掉它 github.com 会连不上'
    Write-Host '  2) 网络抽风？过 10 秒重跑一次 .\push.ps1'
    Write-Host '  3) 远端有新提交？先跑 git pull --rebase'
    Write-Host ''
    Write-Host $push.Out
    exit 1
}

Write-Host ''
Write-Host '上传成功！' -ForegroundColor Green
Write-Host ("  仓库：{0}" -f $repoUrl) -ForegroundColor White
Write-Host ("  提交：{0}  {1}" -f $hash, $Message)
