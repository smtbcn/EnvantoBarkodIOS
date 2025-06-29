package com.envanto.barcode.api;

import com.google.gson.annotations.SerializedName;

public class Customer {
    @SerializedName("musteri_adi")
    private String name;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    @Override
    public String toString() {
        return name;
    }
} 