package com.envanto.barcode.api;

public class LoginRequest {
    private String action;
    private String email;
    private String password;
    
    public LoginRequest(String email, String password) {
        this.action = "login";
        this.email = email;
        this.password = password;
    }
    
    public String getAction() {
        return action;
    }
    
    public String getEmail() {
        return email;
    }
    
    public String getPassword() {
        return password;
    }
} 