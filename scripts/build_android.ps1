# Build ban Android (AAB ky san) de tai len Google Play. Owner chay tren Windows. CHI ASCII (PowerShell 5.1).
# Da chay thu tren Windows PowerShell 5.1 trong CI (.github/workflows/android-build.yml) voi keystore TAM.
#
# Cach chay (PowerShell, o thu muc repo app da checkout main moi nhat):
#   powershell -ExecutionPolicy Bypass -File scripts\build_android.ps1
#
# Script KIEM TRA truoc khi build va DUNG NGAY neu sai:
#   1. Flutter dung phien ban 3.44.2.
#   2. api_constants.dart tro vao server production (khong localhost / 127.0.0.1 / 10.0.2.2).
#   3. android\key.properties va file keystore ton tai (khong in mat khau).
#   4. versionCode trong pubspec.yaml lon hon so owner nhap (versionCode lon nhat da co tren Play Console).
# Sau do: flutter pub get -> flutter build appbundle --release -> in duong dan, kich thuoc, SHA-256 cua file .aab
# va chu ky (SHA-1 cua chung chi) de so voi "Upload key certificate" tren Play Console.
param(
    [string]$Flutter = 'flutter',
    [string]$FlutterVersion = '3.44.2',
    [int]$PlayVersionCode = -1    # versionCode lon nhat tren Play Console; -1 = hoi
)
$ErrorActionPreference = 'Stop'
$failed = $false

function Step([string]$title) { Write-Host ''; Write-Host ('==== ' + $title + ' ====') -ForegroundColor Cyan }

# Lenh native: tam 'Continue' (PS 5.1 + 'Stop' coi moi dong stderr la loi), gom 2>&1, in tung dong, CHI xet exit code.
function Invoke-Native([string]$What, [string]$Exe, [string[]]$ArgList) {
    $lines = New-Object System.Collections.Generic.List[string]
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = $null
    try {
        & $Exe @ArgList 2>&1 | ForEach-Object { $t = [string]$_; $lines.Add($t); Write-Host $t }
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $prev }
    if ($null -eq $code -or $code -ne 0) { throw ($What + ' that bai (exit ' + $code + '). DUNG.') }
    return ,$lines
}

function Read-Number([string]$question) {
    if ([Console]::IsInputRedirected) { $a = [Console]::In.ReadLine() }
    else { try { $Host.UI.RawUI.FlushInputBuffer() } catch { }; $a = Read-Host $question }
    $n = 0
    if (-not [int]::TryParse(([string]$a).Trim(), [ref]$n)) { throw ('Khong phai so: "' + $a + '"') }
    return $n
}

try {
    Step '1/5 Kiem tra Flutter'
    if (-not (Get-Command $Flutter -ErrorAction SilentlyContinue)) { throw ('Khong tim thay lenh ' + $Flutter + ' (them flutter\bin vao PATH).') }
    $fv = (Invoke-Native 'flutter --version' $Flutter @('--version', '--suppress-analytics')) | Out-String
    if ($fv -notmatch ('Flutter ' + [regex]::Escape($FlutterVersion) + ' ')) { throw ('Can Flutter ' + $FlutterVersion + '. Dang dung: ' + (($fv -split "`n")[0]).Trim()) }
    Write-Host ('OK: Flutter ' + $FlutterVersion)

    Step '2/5 Kiem tra cau hinh'
    $api = Get-Content 'lib\core\constants\api_constants.dart' -Raw
    if ($api -match 'localhost|127\.0\.0\.1|10\.0\.2\.2') { throw 'api_constants.dart dang tro vao may local - KHONG build ban phat hanh. Tra lai ban tren main (git checkout -- lib\core\constants\api_constants.dart).' }
    if ($api -notmatch "baseUrl = 'https://taiwanmate-backend-production\.up\.railway\.app/api/v1'") { throw 'baseUrl trong api_constants.dart khong phai server production.' }
    Write-Host 'OK: baseUrl = server production'
    if (-not (Test-Path 'android\key.properties')) { throw 'Thieu android\key.properties (file ky ban phat hanh, khong co trong git).' }
    $kp = @{}
    foreach ($l in Get-Content 'android\key.properties') { if ($l -match '^\s*([^#=]+?)\s*=\s*(.*)$') { $kp[$Matches[1]] = $Matches[2] } }
    foreach ($k in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) { if (-not $kp[$k]) { throw ('key.properties thieu ' + $k) } }
    $store = $kp['storeFile']
    if (-not [System.IO.Path]::IsPathRooted($store)) { $store = Join-Path 'android\app' $store }
    if (-not (Test-Path $store)) { throw ('Khong thay keystore: ' + $kp['storeFile'] + ' (duong dan tuong doi tinh tu android\app).') }
    Write-Host ('OK: keystore ' + (Split-Path $store -Leaf) + ', alias ' + $kp['keyAlias'] + ' (khong in mat khau)')
    $ver = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)\+(\d+)\s*$').Matches
    if (-not $ver) { throw 'Khong doc duoc version trong pubspec.yaml' }
    $vName = $ver[0].Groups[1].Value; $vCode = [int]$ver[0].Groups[2].Value
    Write-Host ('pubspec.yaml: versionName ' + $vName + ', versionCode ' + $vCode)
    if ($PlayVersionCode -lt 0) { $PlayVersionCode = Read-Number 'Nhap versionCode LON NHAT dang co tren Play Console (App bundle explorer)' }
    if ($vCode -le $PlayVersionCode) { throw ('versionCode ' + $vCode + ' <= ' + $PlayVersionCode + ' tren Play - Play se tu choi. Bao CTO tang version trong pubspec.yaml.') }
    Write-Host ('OK: versionCode ' + $vCode + ' > ' + $PlayVersionCode)

    Step '3/5 flutter pub get'
    Invoke-Native 'flutter pub get' $Flutter @('pub', 'get', '--suppress-analytics') | Out-Null

    Step '4/5 flutter build appbundle --release (5-15 phut)'
    Invoke-Native 'flutter build appbundle' $Flutter @('build', 'appbundle', '--release', '--suppress-analytics') | Out-Null

    Step '5/5 Ket qua'
    $aab = 'build\app\outputs\bundle\release\app-release.aab'
    if (-not (Test-Path $aab)) { throw ('Khong thay ' + $aab) }
    $size = [math]::Round((Get-Item $aab).Length / 1MB, 1)
    $sha = (Get-FileHash -Algorithm SHA256 $aab).Hash
    Write-Host ('File: ' + (Resolve-Path $aab) + ' (' + $size + ' MB)')
    Write-Host ('SHA-256: ' + $sha)
    if (Get-Command keytool -ErrorAction SilentlyContinue) {
        $cert = (Invoke-Native 'keytool -printcert' 'keytool' @('-printcert', '-jarfile', $aab)) | Out-String
        if ($cert -match 'SHA1:\s*([0-9A-F:]+)') { Write-Host ('Chu ky SHA-1: ' + $Matches[1] + '  (phai trung "Upload key certificate" tren Play Console)') -ForegroundColor Yellow }
        else { throw 'File .aab KHONG co chu ky - kiem tra key.properties.' }
    } else { Write-Host 'Khong co keytool trong PATH - bo qua in chu ky (Play Console se bao neu sai khoa).' -ForegroundColor Yellow }
    Write-Host ''
    Write-Host ('XONG: ' + $vName + ' (' + $vCode + '). Tai file .aab len Play Console > Testing > Internal testing truoc.') -ForegroundColor Green
}
catch {
    Write-Host ''
    Write-Host ('LOI: ' + $_.Exception.Message) -ForegroundColor Red
    $failed = $true
}
if ($failed) { exit 1 }
