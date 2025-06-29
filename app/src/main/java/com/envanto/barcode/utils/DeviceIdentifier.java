package com.envanto.barcode.utils;

import android.content.Context;
import android.os.Build;
import android.provider.Settings;

/**
 * Cihaz benzersiz kimliği oluşturmak için yardımcı sınıf
 */
public class DeviceIdentifier {
    
    /**
     * Cihaz için benzersiz kimlik olarak Android ID'yi döndürür
     * 
     * @param context Uygulama context'i
     * @return Android ID
     */
    public static String getUniqueDeviceId(Context context) {
        // Android ID'yi al
        return Settings.Secure.getString(context.getContentResolver(), Settings.Secure.ANDROID_ID);
    }
    
    /**
     * Cihaz bilgilerini insan tarafından okunabilir formatta döndürür
     * 
     * @param context Uygulama context'i
     * @return Cihaz bilgileri (format: MARKA MODEL (Android ID))
     */
    public static String getReadableDeviceInfo(Context context) {
        String androidId = getUniqueDeviceId(context);
        return Build.MANUFACTURER + " " + Build.MODEL + " (" + androidId + ")";
    }
} 