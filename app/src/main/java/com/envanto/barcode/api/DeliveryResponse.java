package com.envanto.barcode.api;

public class DeliveryResponse {
    private boolean success;
    private String message;
    private int delivered_count;
    private int total_count;

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

    public int getDelivered_count() {
        return delivered_count;
    }

    public void setDelivered_count(int delivered_count) {
        this.delivered_count = delivered_count;
    }

    public int getTotal_count() {
        return total_count;
    }

    public void setTotal_count(int total_count) {
        this.total_count = total_count;
    }
} 