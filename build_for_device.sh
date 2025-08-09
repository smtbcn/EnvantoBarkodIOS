#!/bin/bash

# Envanto Barkod iOS - Cihaz için Build Script
# Bu script kendi iPhone'unuza build almak için kullanılır

echo "🚀 Envanto Barkod iOS - Cihaz Build Başlatılıyor..."
echo

# Değişkenler
PROJECT_NAME="EnvantoBarkod"
SCHEME_NAME="EnvantoBarkod"
BUNDLE_ID="com.envanto.barcode.ios"
TEAM_ID="6F974S63AX"

# Build klasörünü temizle
echo "🧹 Build klasörü temizleniyor..."
rm -rf build/
mkdir -p build

# Archive oluştur
echo "📦 Archive oluşturuluyor..."
xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    archive \
    -archivePath "build/${PROJECT_NAME}.xcarchive"

if [ $? -ne 0 ]; then
    echo "❌ Archive oluşturma başarısız!"
    exit 1
fi

echo "✅ Archive başarıyla oluşturuldu!"

# Export options oluştur
cat > build/export_options_device.plist << EOF
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
EOF

# IPA export et
echo "📱 IPA export ediliyor..."
xcodebuild \
    -exportArchive \
    -archivePath "build/${PROJECT_NAME}.xcarchive" \
    -exportPath build \
    -exportOptionsPlist build/export_options_device.plist

if [ $? -ne 0 ]; then
    echo "❌ IPA export başarısız!"
    exit 1
fi

echo "🎉 Build başarıyla tamamlandı!"
echo "📁 IPA dosyası: build/${PROJECT_NAME}.ipa"
echo
echo "📱 Kurulum için:"
echo "1. Xcode'da Window > Devices and Simulators"
echo "2. iPhone'unuzu seçin"
echo "3. '+' butonuna tıklayın"
echo "4. build/${PROJECT_NAME}.ipa dosyasını seçin"
echo