#Requires -Version 5.1
<#
.SYNOPSIS
    Anime file and folder renamer — prettifies anime media libraries.

.DESCRIPTION
    Parses common anime file naming patterns (fansub, scene, streaming rips) and
    renames them into clean, consistent naming conventions.

    File output:   [Anime Title] - [Episode] [Resolution] [Group].ext
    Folder output: [Anime Title] ([Year]) [Type] [Resolution]

.PARAMETER Path
    Target directory path to process.

.PARAMETER DryRun
    Preview all changes without actually renaming anything.

.PARAMETER Recurse
    Process subdirectories recursively.

.PARAMETER Undo
    Revert renames using the rename-log.txt file in the target directory.

.PARAMETER Type
    Anime type tag: TV, Movie, OVA, ONA, Special. Default: TV

.PARAMETER Year
    Release year to add to folder names.

.PARAMETER Group
    Override or set the release group tag for all files.

.EXAMPLE
    .\anime-renamer.ps1 -Path "C:\Anime\Naruto" -DryRun
    Preview renames without applying them.

.EXAMPLE
    .\anime-renamer.ps1 -Path "C:\Anime\Naruto" -Type TV -Year 2002
    Rename files and the folder with type and year.

.EXAMPLE
    .\anime-renamer.ps1 -Path "C:\Anime\Naruto" -Recurse
    Recursively process all subdirectories.

.EXAMPLE
    .\anime-renamer.ps1 -Path "C:\Anime\Naruto" -Undo
    Revert all renames using rename-log.txt.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [switch]$DryRun,
    [switch]$Recurse,
    [switch]$Undo,

    [ValidateSet('TV', 'Movie', 'OVA', 'ONA', 'Special')]
    [string]$Type = 'TV',

    [string]$Year = '',
    [string]$Group = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Constants ────────────────────────────────────────────────────────────────

$LogFileName  = 'rename-log.txt'
$VideoExts    = @('.mkv', '.mp4', '.avi', '.m4v', '.mov', '.wmv', '.flv', '.webm', '.ts', '.m2ts')
$IllegalChars = '[/\\:*?"<>|]'

# ─── Helper: Title Case ───────────────────────────────────────────────────────

function ConvertTo-TitleCase {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $ti = (Get-Culture).TextInfo

    # Common short words that stay lowercase unless at start/end of title
    $lowerWords = @('a','an','the','and','but','or','nor','for','so','yet',
                    'at','by','in','of','on','to','up','as','is','it',
                    'no','de','da','di','van','von','el','la','le','les')

    $words = $Text -split '\s+'
    $count = $words.Count
    $result = for ($i = 0; $i -lt $count; $i++) {
        $word = $words[$i]
        # Preserve all-uppercase abbreviations (e.g. CR, WEB, BD)
        if ($word.Length -gt 1 -and $word -ceq $word.ToUpper()) {
            $word
        } elseif ($i -gt 0 -and $i -lt ($count - 1) -and $lowerWords -contains $word.ToLower()) {
            $word.ToLower()
        } else {
            $ti.ToTitleCase($word.ToLower())
        }
    }
    return ($result -join ' ').Trim()
}

# ─── Helper: Clean text ───────────────────────────────────────────────────────

function Invoke-CleanTitle {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }

    # Replace dots/underscores used as word separators with spaces
    # Only replace sequences that look like word separators (not decimals)
    $Text = $Text -replace '_', ' '
    $Text = $Text -replace '\.(?=[A-Za-z])', ' '  # dot followed by letter → space
    $Text = $Text -replace '\.(?=\d{4})', ' '       # dot before 4-digit year → space

    # Remove illegal filename characters
    $Text = $Text -replace $IllegalChars, ''

    # Collapse multiple spaces
    $Text = $Text -replace '\s{2,}', ' '

    return $Text.Trim()
}

# ─── Core: Parse anime filename ───────────────────────────────────────────────

function Get-AnimeInfo {
    <#
    .SYNOPSIS
        Parses an anime filename and returns a hashtable of extracted metadata.
    #>
    param([string]$FileName)

    $info = @{
        Title      = ''
        Episode    = ''
        Version    = ''
        Resolution = ''
        ReleaseGroup = ''
        Hash       = ''
        Source     = ''
        Codec      = ''
    }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)

    # ── Pattern 1: [SubGroup] Anime Title - 01 (1080p) [HASH]
    # ── Pattern 2: [SubGroup] Anime Title - 01v2 (720p) [HASH]
    # ── Pattern 3: [SubGroup]_Anime_Title_-_01_[1080p][HASH]
    # Separator is either a space-dash-space variant or the underscore-encoded _-_
    $fansub = [regex]::Match($base,
        '^\[(?<group>[^\]]+)\]\s*(?<title>.+?)\s*(?:-|_-_)\s*(?<ep>\d{1,4})(?<ver>v\d)?[\s_]*' +
        '(?:\[(?<res>\d{3,4}p|4[Kk]|2160p)\]|\((?<res2>\d{3,4}p|4[Kk]|2160p)\))?' +
        '(?:[\s_]*\[(?<hash>[0-9A-Fa-f]{8})\])?.*$')

    if ($fansub.Success) {
        $info.ReleaseGroup = $fansub.Groups['group'].Value.Trim()
        $info.Title        = (Invoke-CleanTitle $fansub.Groups['title'].Value)
        $info.Episode      = $fansub.Groups['ep'].Value.TrimStart('0').PadLeft(2, '0')
        $info.Version      = $fansub.Groups['ver'].Value
        $res = $fansub.Groups['res'].Value
        if ([string]::IsNullOrEmpty($res)) { $res = $fansub.Groups['res2'].Value }
        $info.Resolution   = $res.ToLower()
        $info.Hash         = $fansub.Groups['hash'].Value
        return $info
    }

    # ── Pattern 4: Scene / streaming — Anime.Title.S01E01.1080p.BluRay.x264-GROUP
    $scene = [regex]::Match($base,
        '^(?<title>.+?)\.S\d{1,2}E(?<ep>\d{1,4})\.(?<res>\d{3,4}p)?.*?(?:-(?<group>[A-Za-z0-9]+))?$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($scene.Success) {
        $info.Title        = (Invoke-CleanTitle $scene.Groups['title'].Value)
        $info.Episode      = $scene.Groups['ep'].Value.TrimStart('0').PadLeft(2, '0')
        $info.Resolution   = $scene.Groups['res'].Value.ToLower()
        $info.ReleaseGroup = $scene.Groups['group'].Value
        return $info
    }

    # ── Pattern 5: Scene without season — Anime.Title.E1015.1080p.WEB.x264-GROUP
    $sceneE = [regex]::Match($base,
        '^(?<title>.+?)\.E(?<ep>\d{1,4})\.(?<res>\d{3,4}p)?.*?(?:-(?<group>[A-Za-z0-9]+))?$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($sceneE.Success) {
        $info.Title        = (Invoke-CleanTitle $sceneE.Groups['title'].Value)
        $info.Episode      = $sceneE.Groups['ep'].Value.TrimStart('0').PadLeft(2, '0')
        $info.Resolution   = $sceneE.Groups['res'].Value.ToLower()
        $info.ReleaseGroup = $sceneE.Groups['group'].Value
        return $info
    }

    # ── Pattern 6: Anime Title Episode 01
    $epWord = [regex]::Match($base,
        '^(?<title>.+?)\s+[Ee]pisode\s+(?<ep>\d{1,4})',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($epWord.Success) {
        $info.Title   = (Invoke-CleanTitle $epWord.Groups['title'].Value)
        $info.Episode = $epWord.Groups['ep'].Value.TrimStart('0').PadLeft(2, '0')
        return $info
    }

    # ── Pattern 7: Generic — Anime Title - 01 [1080p]
    $generic = [regex]::Match($base,
        '^(?<title>.+?)\s*-\s*(?<ep>\d{1,4})(?<ver>v\d)?' +
        '(?:\s*[\[\(](?<res>\d{3,4}p|4[Kk]|2160p)[\]\)])?')

    if ($generic.Success) {
        $info.Title      = (Invoke-CleanTitle $generic.Groups['title'].Value)
        $info.Episode    = $generic.Groups['ep'].Value.TrimStart('0').PadLeft(2, '0')
        $info.Version    = $generic.Groups['ver'].Value
        $info.Resolution = $generic.Groups['res'].Value.ToLower()
        return $info
    }

    # ── Fallback: use entire base as title
    $info.Title = (Invoke-CleanTitle $base)
    return $info
}

# ─── Core: Extract resolution from any bracket in filename ───────────────────

function Get-ResolutionFromName {
    param([string]$Name)
    $m = [regex]::Match($Name, '(4[Kk]|2160p|\d{3,4}p)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) { return $m.Value.ToLower() }
    return ''
}

# ─── Core: Build pretty file name ─────────────────────────────────────────────

function Build-PrettyFileName {
    param(
        [hashtable]$Info,
        [string]$Extension,
        [string]$GroupOverride
    )

    $title = ConvertTo-TitleCase $Info.Title
    $ep    = $Info.Episode
    $res   = $Info.Resolution
    $grp   = if ($GroupOverride) { $GroupOverride } else { $Info.ReleaseGroup }

    $parts = @($title)

    if ($ep) {
        $parts += "- $ep"
    }

    if ($res) {
        $parts += "[$res]"
    }

    if ($grp) {
        $parts += "[$grp]"
    }

    $name = ($parts -join ' ').Trim()
    # Remove any remaining illegal chars
    $name = $name -replace $IllegalChars, ''
    $name = $name -replace '\s{2,}', ' '

    return "$name$Extension"
}

# ─── Core: Build pretty folder name ──────────────────────────────────────────

function Build-PrettyFolderName {
    param(
        [string]$FolderName,
        [string]$TypeTag,
        [string]$YearTag,
        [string]$ResolutionTag
    )

    # Try to extract existing title from the folder — strip resolution/group tags
    $clean = $FolderName -replace '\[.*?\]', ''
    $clean = $clean -replace '\(?\d{3,4}p\)?', ''
    $clean = Invoke-CleanTitle $clean
    $title = ConvertTo-TitleCase $clean

    $parts = @($title)
    if ($YearTag) { $parts += "($YearTag)" }
    if ($TypeTag) { $parts += "[$TypeTag]" }
    if ($ResolutionTag) { $parts += "[$ResolutionTag]" }

    $name = ($parts -join ' ').Trim()
    $name = $name -replace $IllegalChars, ''
    $name = $name -replace '\s{2,}', ' '
    return $name
}

# ─── Undo mode ────────────────────────────────────────────────────────────────

function Invoke-Undo {
    param([string]$DirectoryPath)

    $logPath = Join-Path $DirectoryPath $LogFileName
    if (-not (Test-Path $logPath)) {
        Write-Warning "No rename log found at: $logPath"
        return
    }

    $lines = Get-Content $logPath -Encoding UTF8 | Where-Object { $_ -match '\|' }
    $reverted = 0
    $errors   = 0

    foreach ($line in $lines) {
        # Skip header/separator lines
        if ($line -match '^(TIMESTAMP|[-=]+)') { continue }

        $parts = $line -split '\|'
        if ($parts.Count -lt 3) { continue }

        $oldName = $parts[1].Trim()
        $newName = $parts[2].Trim()

        # Determine directory for this file/folder
        $dir = $parts[3].Trim()
        if (-not $dir) { $dir = $DirectoryPath }

        $newPath = Join-Path $dir $newName
        $oldPath = Join-Path $dir $oldName

        if (-not (Test-Path $newPath)) {
            Write-Warning "Not found (skipping): $newPath"
            continue
        }
        if (Test-Path $oldPath) {
            Write-Warning "Target already exists (skipping): $oldPath"
            continue
        }

        try {
            Rename-Item -LiteralPath $newPath -NewName $oldName -ErrorAction Stop
            Write-Host "  Reverted: $newName → $oldName" -ForegroundColor Cyan
            $reverted++
        } catch {
            Write-Warning "  Failed to revert '$newName': $_"
            $errors++
        }
    }

    Write-Host ''
    Write-Host "Undo complete. Reverted: $reverted  Errors: $errors" -ForegroundColor Green
}

# ─── Logging ──────────────────────────────────────────────────────────────────

function Write-Log {
    param(
        [string]$LogPath,
        [string]$OldName,
        [string]$NewName,
        [string]$Directory
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp | $OldName | $NewName | $Directory"
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

# ─── Process files in a directory ────────────────────────────────────────────

function Invoke-RenameFiles {
    param(
        [string]$DirectoryPath,
        [string]$LogPath,
        [string]$GroupOverride,
        [bool]  $IsDryRun
    )

    $files = Get-ChildItem -LiteralPath $DirectoryPath -File |
             Where-Object { $VideoExts -contains $_.Extension.ToLower() } |
             Sort-Object Name

    $renamed = 0
    $skipped = 0

    foreach ($file in $files) {
        $info = Get-AnimeInfo -FileName $file.Name

        # Fallback resolution from anywhere in the filename
        if (-not $info.Resolution) {
            $info.Resolution = Get-ResolutionFromName $file.Name
        }

        $prettyName = Build-PrettyFileName -Info $info -Extension $file.Extension -GroupOverride $GroupOverride

        if ($prettyName -eq $file.Name) {
            Write-Verbose "  Unchanged: $($file.Name)"
            $skipped++
            continue
        }

        $destPath = Join-Path $DirectoryPath $prettyName

        Write-Host "  $($file.Name)" -ForegroundColor Yellow
        Write-Host "    → $prettyName" -ForegroundColor Green

        if (-not $IsDryRun) {
            if (Test-Path -LiteralPath $destPath) {
                Write-Warning "    Skipped (destination exists): $prettyName"
                $skipped++
                continue
            }
            try {
                Rename-Item -LiteralPath $file.FullName -NewName $prettyName -ErrorAction Stop
                Write-Log -LogPath $LogPath -OldName $file.Name -NewName $prettyName -Directory $DirectoryPath
                $renamed++
            } catch {
                Write-Warning "    Error renaming '$($file.Name)': $_"
                $skipped++
            }
        } else {
            $renamed++
        }
    }

    return @{ Renamed = $renamed; Skipped = $skipped }
}

# ─── Process folder ──────────────────────────────────────────────────────────

function Invoke-RenameFolder {
    param(
        [string]$DirectoryPath,
        [string]$LogPath,
        [string]$TypeTag,
        [string]$YearTag,
        [string]$ResolutionTag,
        [bool]  $IsDryRun
    )

    $dirInfo = Get-Item -LiteralPath $DirectoryPath

    # Determine dominant resolution from files inside
    if (-not $ResolutionTag) {
        $innerFiles = Get-ChildItem -LiteralPath $DirectoryPath -File |
                      Where-Object { $VideoExts -contains $_.Extension.ToLower() } |
                      Select-Object -First 5
        foreach ($f in $innerFiles) {
            $res = Get-ResolutionFromName $f.Name
            if ($res) { $ResolutionTag = $res; break }
        }
    }

    $prettyName = Build-PrettyFolderName `
        -FolderName   $dirInfo.Name `
        -TypeTag      $TypeTag `
        -YearTag      $YearTag `
        -ResolutionTag $ResolutionTag

    if ($prettyName -eq $dirInfo.Name) {
        Write-Host "Folder already pretty: $($dirInfo.Name)" -ForegroundColor Cyan
        return $DirectoryPath
    }

    $parentPath = $dirInfo.Parent.FullName
    $newPath    = Join-Path $parentPath $prettyName

    Write-Host ''
    Write-Host "Folder:" -ForegroundColor Magenta
    Write-Host "  $($dirInfo.Name)" -ForegroundColor Yellow
    Write-Host "  → $prettyName" -ForegroundColor Green

    if (-not $IsDryRun) {
        if (Test-Path -LiteralPath $newPath) {
            Write-Warning "  Skipped folder rename (destination exists): $prettyName"
            return $DirectoryPath
        }
        try {
            Rename-Item -LiteralPath $DirectoryPath -NewName $prettyName -ErrorAction Stop
            Write-Log -LogPath $LogPath -OldName $dirInfo.Name -NewName $prettyName -Directory $parentPath
            return $newPath
        } catch {
            Write-Warning "  Error renaming folder '$($dirInfo.Name)': $_"
            return $DirectoryPath
        }
    }

    return $DirectoryPath
}

# ─── Main ─────────────────────────────────────────────────────────────────────

# Validate path
$resolvedPath = $Path
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    Write-Error "Path not found or not a directory: $resolvedPath"
    exit 1
}
$resolvedPath = (Resolve-Path -LiteralPath $resolvedPath).ProviderPath

# Banner
Write-Host ''
Write-Host '╔══════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║          🎬  Anime Renamer  🎬           ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

if ($DryRun) {
    Write-Host '[DRY RUN] No files will be changed.' -ForegroundColor Yellow
    Write-Host ''
}

# Undo mode
if ($Undo) {
    Write-Host 'Mode: Undo' -ForegroundColor Magenta
    Invoke-Undo -DirectoryPath $resolvedPath
    exit 0
}

# Log file lives in target directory (skip in dry-run)
$logPath = Join-Path $resolvedPath $LogFileName

if (-not $DryRun -and -not (Test-Path $logPath)) {
    $header = "TIMESTAMP                | OLD NAME | NEW NAME | DIRECTORY"
    $sep    = '-' * 80
    Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8
    Add-Content -LiteralPath $logPath -Value $sep    -Encoding UTF8
}

$totalRenamed = 0
$totalSkipped = 0

if ($Recurse) {
    # Process subdirectories first (leaf → root order)
    $subDirs = Get-ChildItem -LiteralPath $resolvedPath -Directory -Recurse |
               Sort-Object FullName -Descending

    foreach ($sub in $subDirs) {
        Write-Host "Processing: $($sub.FullName)" -ForegroundColor Cyan
        $result = Invoke-RenameFiles `
            -DirectoryPath $sub.FullName `
            -LogPath       $logPath `
            -GroupOverride $Group `
            -IsDryRun      $DryRun.IsPresent
        $totalRenamed += $result.Renamed
        $totalSkipped += $result.Skipped
    }
}

# Process files in the target directory
Write-Host "Processing: $resolvedPath" -ForegroundColor Cyan
$result = Invoke-RenameFiles `
    -DirectoryPath $resolvedPath `
    -LogPath       $logPath `
    -GroupOverride $Group `
    -IsDryRun      $DryRun.IsPresent
$totalRenamed += $result.Renamed
$totalSkipped += $result.Skipped

# Rename the target folder itself
$resolvedPath = Invoke-RenameFolder `
    -DirectoryPath $resolvedPath `
    -LogPath       $logPath `
    -TypeTag       $Type `
    -YearTag       $Year `
    -ResolutionTag (Get-ResolutionFromName $resolvedPath) `
    -IsDryRun      $DryRun.IsPresent

# Summary
Write-Host ''
Write-Host '─────────────────────────────────────────────' -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "DRY RUN complete. Would rename: $totalRenamed  Unchanged: $totalSkipped" -ForegroundColor Yellow
} else {
    Write-Host "Done! Renamed: $totalRenamed  Skipped: $totalSkipped" -ForegroundColor Green
    if ($totalRenamed -gt 0) {
        Write-Host "Log saved to: $logPath" -ForegroundColor Gray
    }
}
Write-Host ''
