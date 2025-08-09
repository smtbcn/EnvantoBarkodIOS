# Hızlı Test - Direkt Xcode ile iPhone'a build
Write-Host "📱 Hızlı Test - iPhone'a Direkt Build" -ForegroundColor Green
Write-Host ""

# iPhone bağlı mı kontrol et
Write-Host "🔍 Bağlı cihazları kontrol ediliyor..." -ForegroundColor Yellow
xcrun devicectl list devices

Write-Host ""
Write-Host "📦 Xcode ile direkt build başlatılıyor..." -ForegroundColor Yellow

# Direkt iPhone'a build ve install
xcodebuild -project "EnvantoBarkod.xcodeproj" -scheme "EnvantoBarkod" -configuration Debug -destination "platform=iOS,id=00008140-001469903469801C" -allowProvisioningUpdates DEVELOPMENT_TEAM="6F974S63AX" CODE_SIGN_STYLE=Automatic build

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build başarılı!" -ForegroundColor Green
    Write-Host "📱 Uygulama iPhone'unuzda kurulu olmalı" -ForegroundColor Cyan
} else {
    Write-Host "❌ Build başarısız!" -ForegroundColor Red
    Write-Host "Apple Developer Portal'da cihazınızı kaydetmeyi deneyin" -ForegroundColor Yellow
}