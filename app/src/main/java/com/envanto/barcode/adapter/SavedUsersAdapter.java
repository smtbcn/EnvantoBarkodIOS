package com.envanto.barcode.adapter;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageButton;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.envanto.barcode.R;
import com.envanto.barcode.utils.LoginManager;

import java.util.List;

/**
 * Kayıtlı kullanıcılar için RecyclerView Adapter
 */
public class SavedUsersAdapter extends RecyclerView.Adapter<SavedUsersAdapter.SavedUserViewHolder> {

    private List<LoginManager.SavedUser> savedUsers;
    private OnSavedUserClickListener listener;

    public interface OnSavedUserClickListener {
        void onUserClick(LoginManager.SavedUser user);
        void onUserDelete(LoginManager.SavedUser user);
    }

    public SavedUsersAdapter(List<LoginManager.SavedUser> savedUsers, OnSavedUserClickListener listener) {
        this.savedUsers = savedUsers;
        this.listener = listener;
    }

    @NonNull
    @Override
    public SavedUserViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_saved_user, parent, false);
        return new SavedUserViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull SavedUserViewHolder holder, int position) {
        LoginManager.SavedUser user = savedUsers.get(position);
        holder.bind(user);
    }

    @Override
    public int getItemCount() {
        return savedUsers.size();
    }

    public void updateUsers(List<LoginManager.SavedUser> newUsers) {
        this.savedUsers = newUsers;
        notifyDataSetChanged();
    }

    class SavedUserViewHolder extends RecyclerView.ViewHolder {
        private TextView userNameTextView;
        private TextView userEmailTextView;
        private ImageButton deleteUserButton;

        public SavedUserViewHolder(@NonNull View itemView) {
            super(itemView);
            userNameTextView = itemView.findViewById(R.id.userNameTextView);
            userEmailTextView = itemView.findViewById(R.id.userEmailTextView);
            deleteUserButton = itemView.findViewById(R.id.deleteUserButton);
        }

        public void bind(LoginManager.SavedUser user) {
            userNameTextView.setText(user.getFullName());
            userEmailTextView.setText(user.getEmail());

            // Kullanıcı seçme
            itemView.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onUserClick(user);
                }
            });

            // Kullanıcı silme
            deleteUserButton.setOnClickListener(v -> {
                if (listener != null) {
                    listener.onUserDelete(user);
                }
            });
        }
    }
} 