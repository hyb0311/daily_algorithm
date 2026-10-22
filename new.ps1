#Requires -Version 5.1
<#
    new.ps1  —  一键新建当天题解（Python + C++ 各一份模板）

    用法：
        .\new.ps1 2 "有效的括号"                    # 生成 python/day002.py 和 cpp/day002.cpp
        .\new.ps1 2 "有效的括号" -Slug valid_paren  # 生成 day002_valid_paren.py / .cpp
        .\new.ps1 3 "合并区间" -NoCpp               # 只要 Python
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [int]$Day,

    [Parameter(Position = 1)]
    [string]$Title = '',

    [string]$Slug = '',
    [switch]$NoCpp
)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$dayTag = 'day{0:D3}' -f $Day
$base   = if ($Slug) { '{0}_{1}' -f $dayTag, $Slug } else { $dayTag }
$displayTitle = if ($Title) { $Title } else { '（待填）' }

$targets = @(Join-Path $root ('python\' + $base + '.py'))
if (-not $NoCpp) { $targets += (Join-Path $root ('cpp\' + $base + '.cpp')) }

# 已存在就不动，避免覆盖你写了一半的代码
foreach ($t in $targets) {
    if (Test-Path -LiteralPath $t) { throw "文件已存在，未做任何改动：$t" }
}

$pyTemplate = @"
"""$dayTag - $displayTitle

题目：

思路：
  时间复杂度：O(?)
  空间复杂度：O(?)
"""


def solve():
    pass


def main() -> None:
    # TODO: 用 assert 固定住预期结果
    pass


if __name__ == "__main__":
    main()
"@

$cppTemplate = @"
// $dayTag - $displayTitle
// 思路：
// 时间复杂度：O(?)
// 编译：g++ -std=c++17 -O2 -Wall $base.cpp -o $base.exe
#include <bits/stdc++.h>
using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    // TODO

    return 0;
}
"@

$created = @()
[System.IO.File]::WriteAllText($targets[0], $pyTemplate, $utf8NoBom)
$created += $targets[0]
if (-not $NoCpp) {
    [System.IO.File]::WriteAllText($targets[1], $cppTemplate, $utf8NoBom)
    $created += $targets[1]
}

Write-Host '已创建：' -ForegroundColor Green
foreach ($c in $created) { Write-Host "  $c" }

Write-Host ''
Write-Host '写完后的流程：' -ForegroundColor Cyan
Write-Host '  python python\' -NoNewline
Write-Host ($base + '.py') -ForegroundColor White
Write-Host '  git add .'
Write-Host ('  git commit -m "' + $dayTag + ': ' + $(if ($Title) { $Title } else { 'TODO' }) + '"')
Write-Host '  git push'
