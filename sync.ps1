# Copies the addon into the live WoW AddOns folder.
#
# A symlink would be nicer, but Windows refuses junctions across volumes and
# cross-volume symlinks need an elevated shell - and a project on C: with the
# game on D: is the common case. So: copy, then /reload in game.
#
#   .\sync.ps1                          auto-detect the AddOns folder
#   .\sync.ps1 -Target "E:\WoW\..."     point it somewhere explicitly
#
# Or set WOW_ADDONS once and forget about it:
#   setx WOW_ADDONS "D:\World of Warcraft\_retail_\Interface\AddOns"

param(
    [string]$Target
)

$source = $PSScriptRoot

function Find-AddOnsFolder {
    if ($Target) { return $Target }
    if ($env:WOW_ADDONS) { return $env:WOW_ADDONS }

    $candidates = @()
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Name) {
        $candidates += "${drive}:\World of Warcraft\_retail_\Interface\AddOns"
        $candidates += "${drive}:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
        $candidates += "${drive}:\Games\World of Warcraft\_retail_\Interface\AddOns"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

$addons = Find-AddOnsFolder
if (-not $addons) {
    Write-Error "Could not find the WoW AddOns folder. Pass -Target, or set WOW_ADDONS."
    exit 1
}
if (-not (Test-Path $addons)) {
    Write-Error "AddOns folder does not exist: $addons"
    exit 1
}

$destination = Join-Path $addons "Kicker"
New-Item -ItemType Directory -Force $destination | Out-Null

robocopy $source $destination /MIR `
    /XD .git .github node_modules tests docs `
    /XF *.ps1 *.js *.json *.md *.png .gitignore `
    /NFL /NDL /NJH /NJS /NC /NS | Out-Null

# robocopy signals success with codes below 8; only 8 and up are real failures.
if ($LASTEXITCODE -ge 8) {
    Write-Error "robocopy failed with code $LASTEXITCODE"
    exit 1
}

# The TOC carries @project-version@ so the packager can stamp the real version
# from the git tag. Unsubstituted it would show up verbatim in the addon list,
# so local copies get a readable placeholder instead.
$toc = Join-Path $destination "Kicker.toc"
if (Test-Path $toc) {
    $stamp = "dev-$(git -C $source rev-parse --short HEAD 2>$null)"
    if ($stamp -eq "dev-") { $stamp = "dev" }
    (Get-Content $toc -Raw).Replace("@project-version@", $stamp) |
        Set-Content $toc -Encoding utf8 -NoNewline
}

Write-Host "Synced to $destination - type /reload in game." -ForegroundColor Green
exit 0
