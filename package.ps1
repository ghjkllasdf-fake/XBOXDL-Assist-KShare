param([Parameter(Mandatory)] [string] $GeoArchive)

$ErrorActionPreference = 'Stop'
$geoInput = (Resolve-Path -LiteralPath $GeoArchive).Path
$geoHash = '5F10DF99BC7A88F7632C5F45DE8D189FE01F39D946AB59719F4814D4C34FA198'
if ((Get-FileHash -LiteralPath $geoInput -Algorithm SHA256).Hash -cne $geoHash) { throw 'Incorrect offline attribution snapshot' }
$geoMembers = @(& tar.exe -tzf $geoInput)
if ($LASTEXITCODE -or $geoMembers.Count -ne 223 -or @($geoMembers | Sort-Object -Unique).Count -ne 223 -or
    'LICENSE.ip2region.md' -cnotin $geoMembers -or 'NOTICE.txt' -cnotin $geoMembers -or
    @($geoMembers | Where-Object { $_ -cnotmatch '^(?:(?:0|[1-9]\d?|1\d\d|2[0-4]\d|25[0-5])\.dat\.gz|LICENSE\.ip2region\.md|NOTICE\.txt)$' }).Count) {
    throw 'Unexpected offline attribution members'
}
$geoTypes = @(& tar.exe -tvzf $geoInput)
if ($LASTEXITCODE -or $geoTypes.Count -ne 223 -or @($geoTypes -notmatch '^-').Count) { throw 'Attribution snapshot must contain only regular files' }
Set-Location -LiteralPath $PSScriptRoot
$version = '0.0.1'
$output = Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts'
$installFiles = @('LICENSE', 'README.md', 'RELEASE-NOTES.md', 'RELEASE-QA.md', 'plugin-preview.png', 'xbfast-geo.awk', 'xbfast-icon.png', 'xbfast-lighttpd.conf', 'xbfast-test.sh', 'xbfast.sh')
$sourceFiles = $installFiles + @('.gitignore', 'PUBLISHING.md', 'package.ps1', 'xbfast-geo-test.sh', 'xbfast-install.sh', 'xbfast-runtime-test.sh', 'xbfast-ui-boot-test.cjs', 'xbfast-ui-terra.css', 'xbfast-ui.asp')
$binary = Join-Path $output "xbfast-$version.tar.gz"
$sources = Join-Path $output "xbfast-$version-source.tar.gz"
foreach ($archive in @($binary, $sources)) {
    if (Test-Path -LiteralPath $archive) { throw "Frozen archive already exists: $archive" }
}
foreach ($file in $sourceFiles) {
    $item = Get-Item -Force -LiteralPath $file
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Not a regular source file: $file" }
}
$marker = '<!-- XBFAST_INLINE_CSS -->'
$template = Get-Content -Raw -Encoding utf8 -LiteralPath 'xbfast-ui.asp'
$css = Get-Content -Raw -Encoding utf8 -LiteralPath 'xbfast-ui-terra.css'
if ([regex]::Matches($template, [regex]::Escape($marker)).Count -ne 1 -or
    [string]::IsNullOrWhiteSpace($css) -or $css -match '<\s*/\s*style\b|<%') { throw 'Invalid UI stylesheet or marker' }
$stage = Join-Path $output ('stage-' + [guid]::NewGuid().ToString('N'))
$plugin = Join-Path $stage 'xbfast'
$code = Join-Path $stage "xbfast-$version-source"
New-Item -ItemType Directory -Path $plugin, $code | Out-Null
$geo = Join-Path $plugin 'geo'
New-Item -ItemType Directory -Path $geo | Out-Null
& tar.exe -xzf $geoInput -C $geo
if ($LASTEXITCODE) { throw 'Could not extract offline attribution snapshot' }
foreach ($file in $installFiles) { Copy-Item -LiteralPath $file -Destination $plugin }
Copy-Item -LiteralPath 'xbfast-install.sh' -Destination (Join-Path $plugin 'install.sh')
[IO.File]::WriteAllText((Join-Path $plugin 'xbfast-ui.asp'),
    $template.Replace($marker, "<style id=`"xbfastStyles`">`n$css`n</style>"), [Text.UTF8Encoding]::new($false))
foreach ($file in $sourceFiles) { Copy-Item -Force -LiteralPath $file -Destination $code }
$installMembers = $installFiles + @('install.sh', 'xbfast-ui.asp', 'geo/') + @($geoMembers | ForEach-Object { "geo/$_" })
foreach ($item in @(@($binary, $plugin, $installMembers), @($sources, $code, $sourceFiles))) {
    $archive, $directory, $files = $item
    $prefix = Split-Path -Leaf $directory
    & tar.exe -czf $archive -C $stage $prefix
    if ($LASTEXITCODE) { throw "Could not create $archive" }
    $members = @(& tar.exe -tzf $archive)
    $expected = @("$prefix/") + @($files | ForEach-Object { "$prefix/$_" })
    if ($LASTEXITCODE -or (Compare-Object $expected $members -CaseSensitive)) { throw "Unexpected contents: $archive" }
    Get-FileHash -LiteralPath $archive -Algorithm SHA256
}
