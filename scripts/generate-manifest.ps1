<#
.SYNOPSIS
    扫描 images/ 目录下的图片文件，生成 images/manifest.json 清单。

.DESCRIPTION
    支持 png / jpg / jpeg / webp / gif，按文件名自然排序（2.png 排在 10.png 之前）。
    输出格式为 { "files": ["1.png", "2.png"] }，UTF-8 无 BOM。
    生成后 index.html 会优先使用清单中的图片，适合文件名不连续的场景。

.EXAMPLE
    pwsh -File scripts/generate-manifest.ps1
#>
[CmdletBinding()]
param(
    [string]$ImagesDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'images'),
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if (-not $OutputPath) {
    $OutputPath = Join-Path $ImagesDir 'manifest.json'
}

if (-not (Test-Path -LiteralPath $ImagesDir -PathType Container)) {
    Write-Host "未找到图片目录：$ImagesDir"
    exit 1
}

# 自然排序键：把每一段连续数字补齐，使 2 排在 10 之前
function Get-NaturalKey {
    param([string]$Text)

    $sb = New-Object System.Text.StringBuilder
    $i = 0
    while ($i -lt $Text.Length) {
        $ch = $Text[$i]
        if ([char]::IsDigit($ch)) {
            $start = $i
            while ($i -lt $Text.Length -and [char]::IsDigit($Text[$i])) { $i++ }
            $num = $Text.Substring($start, $i - $start)
            [void]$sb.Append($num.PadLeft(12, '0'))
        }
        else {
            [void]$sb.Append([char]::ToLowerInvariant($ch))
            $i++
        }
    }
    return $sb.ToString()
}

$pattern = '\.(png|jpg|jpeg|webp|gif)$'

$files = Get-ChildItem -LiteralPath $ImagesDir -File |
    Where-Object { $_.Extension -match '^' + $pattern } |
    Sort-Object -Property @{ Expression = { Get-NaturalKey $_.Name } }, Name |
    ForEach-Object { $_.Name }

$names = @($files)

$data = [pscustomobject]@{ files = [string[]]$names }
$json = ConvertTo-Json -InputObject $data -Depth 3

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)

Write-Host "已生成清单：$OutputPath"
Write-Host ("共 " + $names.Count + " 个文件")
if ($names.Count -gt 0) {
    $names | ForEach-Object { Write-Host ("  - " + $_) }
}
else {
    Write-Host "提示：images/ 目录下没有可用的图片文件。"
}
