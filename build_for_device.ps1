# Envanto Barkod iOS - Cihaz için Build Script (PowerShell)
# Bu script kendi iPhone'unuza build almak için kullanılır

Write-Host "🚀 Envanto Barkod iOS - Cihaz Build Başlatılıyor..." -ForegroundColor Green
Write-Host ""

# Değişkenler
$PROJECT_NAME = "EnvantoBarkod"
$SCHEME_NAME = "EnvantoBarkod"
$BUNDLE_ID = "com.envanto.barcode.ios"
$TEAM_ID = "6F974S63AX"

# Build klasörünü temizle
Write-Host "🧹 Build klasörü temizleniyor..." -ForegroundColor Yellow
if (Test-Path "build") {
    Remove-Item -Recurse -Force "build"
}
New-Item -ItemType Directory -Path "build" -Force | Out-Null

# Archive oluştur
Write-Host "📦 Archive oluşturuluyor..." -ForegroundColor Yellow
$archiveCmd = @"
xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" -configuration Debug -destination 'generic/platform=iOS' -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic archive -archivePath "build/$PROJECT_NAME.xcarchive"
"@

Invoke-Expression $archiveCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Archive oluşturma başarısız!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Archive başarıyla oluşturuldu!" -ForegroundColor Green

# Export options oluştur
$exportOptions = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string></string>
    </dict>
</dict>
</plist>
"@

$exportOptions | Out-File -FilePath "build/export_options_device.plist" -Encoding UTF8

# IPA export et
Write-Host "📱 IPA export ediliyor..." -ForegroundColor Yellow
$exportCmd = @"
xcodebuild -exportArchive -archivePath "build/$PROJECT_NAME.xcarchive" -exportPath build -exportOptionsPlist build/export_options_device.plist
"@

Invoke-Expression $exportCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ IPA export başarısız!" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Build başarıyla tamamlandı!" -ForegroundColor Green
Write-Host "📁 IPA dosyası: build/$PROJECT_NAME.ipa" -ForegroundColor Cyan
Write-Host ""
Write-Host "📱 Kurulum için:" -ForegroundColor Yellow
Write-Host "1. Xcode'da Window > Devices and Simulators"
Write-Host "2. iPhone'unuzu seçin"
Write-Host "3. '+' butonuna tıklayın"
Write-Host "4. build/$PROJECT_NAME.ipa dosyasını seçin"
Write-Host ""