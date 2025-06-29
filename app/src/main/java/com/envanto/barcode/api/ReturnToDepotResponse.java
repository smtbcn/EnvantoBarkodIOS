package com.envanto.barcode.api;

public class ReturnToDepotResponse {
    private boolean success;
    private String message;
    private String transfer_depo;

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public String getTransfer_depo() {
        return transfer_depo;
    }

    public void setTransfer_depo(String transfer_depo) {
        this.transfer_depo = transfer_depo;
    }
} 