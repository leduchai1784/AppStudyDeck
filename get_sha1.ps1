# Script to get SHA-1 fingerprint for Android debug keystore
# Usage: .\get_sha1.ps1

Write-Host "🔍 Đang tìm SHA-1 fingerprint cho Android debug keystore..." -ForegroundColor Cyan

# Tìm Java installation
$javaPaths = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "$env:ProgramFiles\Java\*\bin\keytool.exe",
    "$env:ProgramFiles(x86)\Java\*\bin\keytool.exe",
    "$env:LOCALAPPDATA\Android\Sdk\jbr\bin\keytool.exe",
    "$env:LOCALAPPDATA\Android\Sdk\jre\bin\keytool.exe"
)

$keytoolPath = $null
foreach ($path in $javaPaths) {
    $found = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $keytoolPath = $found.FullName
        break
    }
}

if (-not $keytoolPath) {
    Write-Host "❌ Không tìm thấy keytool. Vui lòng:" -ForegroundColor Red
    Write-Host "   1. Cài đặt Java JDK" -ForegroundColor Yellow
    Write-Host "   2. Hoặc thêm JAVA_HOME vào environment variables" -ForegroundColor Yellow
    Write-Host "   3. Hoặc chạy lệnh sau trong Android Studio Terminal:" -ForegroundColor Yellow
    Write-Host "      cd android && gradlew signingReport" -ForegroundColor Green
    exit 1
}

Write-Host "✅ Tìm thấy keytool tại: $keytoolPath" -ForegroundColor Green

# Đường dẫn debug keystore
$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

if (-not (Test-Path $debugKeystore)) {
    Write-Host "⚠️  Debug keystore chưa tồn tại tại: $debugKeystore" -ForegroundColor Yellow
    Write-Host "   Keystore sẽ được tạo tự động khi bạn build app lần đầu." -ForegroundColor Yellow
    Write-Host "   Vui lòng chạy: flutter build apk --debug" -ForegroundColor Green
    exit 1
}

Write-Host "📦 Đang lấy SHA-1 từ debug keystore..." -ForegroundColor Cyan
Write-Host ""

# Lấy SHA-1 fingerprint
& $keytoolPath -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android 2>&1 | Select-String -Pattern "SHA1|SHA-1" -Context 0,2

Write-Host ""
Write-Host "💡 Để copy SHA-1, chạy lệnh sau:" -ForegroundColor Cyan
Write-Host "   & '$keytoolPath' -list -v -keystore '$debugKeystore' -alias androiddebugkey -storepass android -keypass android | Select-String -Pattern 'SHA1:'" -ForegroundColor Green

