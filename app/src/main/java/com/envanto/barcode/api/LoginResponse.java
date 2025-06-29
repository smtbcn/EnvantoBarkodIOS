package com.envanto.barcode.api;

public class LoginResponse {
    private boolean success;
    private String message;
    private String error_code;
    private User user;
    
    public boolean isSuccess() {
        return success;
    }
    
    public String getMessage() {
        return message;
    }
    
    public String getErrorCode() {
        return error_code;
    }
    
    public User getUser() {
        return user;
    }
    
    public static class User {
        private String email;
        private String name;
        private String surname;
        private int permission;
        private String token;
        private String last_login;
        private int user_id;
        
        public String getEmail() {
            return email;
        }
        
        public String getName() {
            return name;
        }
        
        public String getSurname() {
            return surname;
        }
        
        public int getPermission() {
            return permission;
        }
        
        public String getToken() {
            return token;
        }
        
        public String getLastLogin() {
            return last_login;
        }
        
        public int getUserId() {
            return user_id;
        }
        
        public String getFullName() {
            return (name != null ? name : "") + " " + (surname != null ? surname : "");
        }
    }
} 