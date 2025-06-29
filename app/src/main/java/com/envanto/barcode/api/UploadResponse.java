package com.envanto.barcode.api;

import com.google.gson.annotations.SerializedName;
import android.util.Log;

public class UploadResponse {
    private static final String TAG = "UploadResponse";

    @SerializedName(value = "basari", alternate = {"success", "status"})
    private boolean success;

    @SerializedName(value = "mesaj", alternate = {"message", "msg"})
    private String message;

    @SerializedName(value = "hata", alternate = {"error", "err"})
    private String error;

    public boolean isSuccess() {
        Log.d(TAG, "Success value: " + success);
        return success;
    }

    public String getMessage() {
        Log.d(TAG, "Message value: " + message);
        return message;
    }

    public String getError() {
        Log.d(TAG, "Error value: " + error);
        return error;
    }

    @Override
    public String toString() {
        return "UploadResponse{" +
                "success=" + success +
                ", message='" + message + '\'' +
                ", error='" + error + '\'' +
                '}';
    }
} 