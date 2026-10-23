#Requires -Version 5.1
<#
    push.ps1  —  一键把你的代码提交并上传到 GitHub

    用法：
        .\push.ps1                       # 自动生成提交说明
        .\push.ps1 "day003: 合并区间"     # 自己指定说明
        .\push.ps1 -NoPush               # 只提交，不上传（本地存档）
        .\push.ps1 -Force                # 跳过删除确认

    安全机制：如果检测到「删除文件」，会先列出来并要求你确认，
    避免把误删的文件同步到 GitHub 上（这个坑真的踩过）。

    如果远端有你在网页上改过、本地还没有的提交，脚本会自动 fetch + rebase
    再重试一次推送；合并冲突时自动回滚，不会留下半截状态。

    没有新改动、但之前有提交还没传上去时，也会照样上传，不会误报「无需上传」。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Message,

    [switch]$NoPush,
    [switch]$Force
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
$hasChanges = [bool]$status.Out

# 工作区干净时也要看一眼有没有之前提交了却没传上去的（比如上次推送被拒）。
$ahead = Invoke-Git @('rev-list','--count','@{u}..HEAD')
$aheadCount = if ($ahead.Code -eq 0 -and $ahead.Out -match '^\d+$') { [int]$ahead.Out } else { 0 }

if (-not $hasChanges) {
    if ($aheadCount -le 0) {
        Write-Host '没有检测到任何改动，也没有待上传的提交，无需上传。' -ForegroundColor Yellow
        Write-Host '（代码要放在这个目录里才会被 git 跟踪：' -NoNewline
        Write-Host $root -NoNewline -ForegroundColor White
        Write-Host '）'

        # 被 .gitignore 挡住的文件 git 根本看不见，主动列出来，免得以为已经传上去了。
        $ignored = Invoke-Git @('ls-files','--others','--ignored','--exclude-standard')
        if ($ignored.Out) {
            $noise = '__pycache__|\.pyc$|\.class$|\.jar$|\.exe$|\.o$|\.obj$|\.pdb$|\.ilk$|\.log$|\.DS_Store$|Thumbs\.db$|desktop\.ini$|^\.venv/|^venv/|^\.vscode/|^\.idea/'
            $ignoredFiles = @($ignored.Out -split "`n" | ForEach-Object { $_.Trim() } |
                              Where-Object { $_ -and $_ -notmatch $noise })
            if ($ignoredFiles.Count -gt 0) {
                Write-Host ''
                Write-Host '但这些文件被 .gitignore 忽略了，不会上传：' -ForegroundColor DarkYellow
                $ignoredFiles | Select-Object -First 10 | ForEach-Object { Write-Host ('    - ' + $_) -ForegroundColor DarkGray }
                if ($ignoredFiles.Count -gt 10) {
                    Write-Host ("    ...还有 {0} 个" -f ($ignoredFiles.Count - 10)) -ForegroundColor DarkGray
                }
                Write-Host '  目录名如果刚好是 bin/ obj/ out/ build/ dist/ tmp/ notes/，就会被忽略；' -ForegroundColor DarkGray
                Write-Host '  换个名字，或在 .gitignore 末尾加一行 !要保留的路径 白名单掉。' -ForegroundColor DarkGray
            }
        }
        exit 0
    }
    Write-Host ("没有新改动，但有 {0} 个提交还没上传，直接上传。" -f $aheadCount) -ForegroundColor Yellow
    $hash = (Invoke-Git @('rev-parse','--short','HEAD')).Out
}

if ($hasChanges) {
    $changed = @($status.Out -split "`n" | Where-Object { $_.Trim() })
    Write-Host ("检测到 {0} 处改动：" -f $changed.Count) -ForegroundColor Cyan
    $changed | ForEach-Object { Write-Host ("  " + $_.Trim()) }

    # ---------- 2. 删除确认（防止误删被同步上去）----------
    $deleted = Invoke-Git @('diff','--cached','--diff-filter=D','--name-only')
    if ($deleted.Out) {
        $delFiles = @($deleted.Out -split "`n" | Where-Object { $_.Trim() })
        Write-Host ''
        Write-Host '⚠ 注意：这次有文件被删除，它们会从 GitHub 上一起消失：' -ForegroundColor Yellow
        $delFiles | ForEach-Object { Write-Host ('    - ' + $_.Trim()) -ForegroundColor Yellow }
        Write-Host '  改正方法：git restore <文件名>  可以把它恢复回来' -ForegroundColor DarkGray

        if (-not $Force) {
            $answer = ''
            try { $answer = Read-Host '确实要删除并上传吗？输入 y 继续，直接回车取消' } catch { $answer = '' }
            if ($answer -notmatch '^[yY]') {
                Invoke-Git @('reset','-q') | Out-Null
                Write-Host '已取消，没有提交任何内容（文件也没动）。' -ForegroundColor Green
                exit 0
            }
        }
    }

    # ---------- 3. 生成提交说明 ----------
    if (-not $Message -or $Message.Trim() -eq '') {
        $dayHit = [regex]::Matches(($changed -join ' '), 'day(\d{3})') |
                  ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Descending | Select-Object -First 1
        if ($dayHit) {
            $Message = ('day{0:D3}: 更新 {1} 个文件' -f $dayHit, $changed.Count)
        } else {
            $Message = ('update: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
        }
    }

    # ---------- 4. 提交 ----------
    $commit = Invoke-Git @('commit','-m',$Message)
    if ($commit.Code -ne 0) {
        Write-Host "提交失败：$($commit.Out)" -ForegroundColor Red
        exit 1
    }
    $hash = (Invoke-Git @('rev-parse','--short','HEAD')).Out
    Write-Host ''
    Write-Host ("已提交 [{0}] {1}" -f $hash, $Message) -ForegroundColor Green
}

if ($NoPush) {
    Write-Host '已按 -NoPush 跳过上传。' -ForegroundColor Yellow
    exit 0
}

# ---------- 5. 上传 ----------
Write-Host '正在上传到 GitHub ...' -ForegroundColor Cyan
$push = Invoke-Git @('-c','http.schannelCheckRevoke=false','push')

# 远端有本地没有的提交（例如在 GitHub 网页上直接改过文件）时，git 会拒绝推送。
# 这不是网络问题，自动 fetch + rebase 再重试一次，不用手动处理。
if ($push.Code -ne 0 -and $push.Out -match 'fetch first|non-fast-forward|Updates were rejected') {
    Write-Host ''
    Write-Host '远端有你本地还没有的提交（不是网络问题），正在合并进来 ...' -ForegroundColor Yellow

    $fetch = Invoke-Git @('fetch','origin')
    if ($fetch.Code -ne 0) {
        Write-Host "拉取远端失败：$($fetch.Out)" -ForegroundColor Red
        Write-Host '这种情况才可能是网络问题：确认 Watt Toolkit(Steam++) 在运行，然后重跑 .\push.ps1'
        exit 1
    }

    $branch = (Invoke-Git @('rev-parse','--abbrev-ref','HEAD')).Out
    $incoming = Invoke-Git @('log','--oneline',"HEAD..origin/$branch")
    if ($incoming.Out) {
        Write-Host '远端新增的提交：' -ForegroundColor Cyan
        $incoming.Out -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { Write-Host ('  ' + $_.Trim()) }
    }

    $rebase = Invoke-Git @('rebase',"origin/$branch")
    if ($rebase.Code -ne 0) {
        Invoke-Git @('rebase','--abort') | Out-Null
        Write-Host ''
        Write-Host '自动合并失败：你和远端改了同一处，已回滚到上传前的状态，提交没丢。' -ForegroundColor Red
        Write-Host '解决办法：手动跑 git pull --rebase，解决冲突后再跑一次 .\push.ps1' -ForegroundColor Yellow
        Write-Host ''
        Write-Host $rebase.Out
        exit 1
    }

    Write-Host '合并完成，重新上传 ...' -ForegroundColor Cyan
    $push = Invoke-Git @('-c','http.schannelCheckRevoke=false','push')
}

if ($push.Code -ne 0) {
    Write-Host ''
    Write-Host '上传失败。排查顺序：' -ForegroundColor Red
    Write-Host '  1) Watt Toolkit(Steam++) 是否在运行？关掉它 github.com 会连不上'
    Write-Host '  2) 网络抽风？过 10 秒重跑一次 .\push.ps1'
    Write-Host '  3) 账号没权限？git remote -v 看下地址里的用户名对不对'
    Write-Host ''
    Write-Host $push.Out
    exit 1
}

# rebase 会改写提交号，成功后再取一次，保证显示的是真正推上去的那个。
$hash = (Invoke-Git @('rev-parse','--short','HEAD')).Out

Write-Host ''
Write-Host '上传成功！' -ForegroundColor Green
Write-Host ("  仓库：{0}" -f $repoUrl) -ForegroundColor White
if ($Message) {
    Write-Host ("  提交：{0}  {1}" -f $hash, $Message)
} else {
    Write-Host ("  提交：{0}" -f $hash)
}
