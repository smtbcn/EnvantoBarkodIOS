package com.envanto.barcode.api;

import com.google.gson.annotations.SerializedName;
import android.util.Log;

public class DeviceAuthResponse {
    private static final String TAG = "DeviceAuthResponse";

    @SerializedName(value = "success", alternate = {"basari", "status"})
    private boolean success;

    @SerializedName(value = "message", alternate = {"mesaj", "msg"})
    private String message;
    
    @SerializedName(value = "cihaz_sahibi", alternate = {"device_owner"})
    private String deviceOwner;

    public boolean isSuccess() {
        Log.d(TAG, "Success value: " + success);
        return success;
    }

    public String getMessage() {
        Log.d(TAG, "Message value: " + message);
        return message;
    }
    
    public String getDeviceOwner() {
        Log.d(TAG, "Device owner value: " + deviceOwner);
        return deviceOwner != null ? deviceOwner : "";
    }

    @Override
    public String toString() {
        return "DeviceAuthResponse{" +
                "success=" + success +
                ", message='" + message + '\'' +
                ", deviceOwner='" + deviceOwner + '\'' +
                '}';
    }
} 