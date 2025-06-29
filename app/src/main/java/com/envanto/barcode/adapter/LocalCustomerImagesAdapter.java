package com.envanto.barcode.adapter;

import android.content.Context;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.envanto.barcode.R;
import com.envanto.barcode.database.DatabaseHelper;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import android.content.SharedPreferences;

/**
 * Müşteri Resimleri Sayfası için özel adapter
 * Sadece lokal resim yönetimi - sunucu yükleme özelliği YOK
 */
public class LocalCustomerImagesAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private static final int TYPE_HEADER = 0;
    private static final int TYPE_IMAGE = 1;
    
    private Context context;
    private Cursor cursor;
    private List<Object> items = new ArrayList<>();
    private Map<String, Boolean> expandedStates = new HashMap<>();
    private Map<String, List<ImageItem>> customerGroups = new HashMap<>();
    private OnImageActionListener listener;
    
    public interface OnImageActionListener {
        void onImageDelete(int id, String imagePath);
        void onImageView(String imagePath);
        void onCustomerDelete(String customerName);
        void onWhatsAppShare(String customerName, List<String> imagePaths);
    }
    
    // Header için ViewHolder
    public static class HeaderViewHolder extends RecyclerView.ViewHolder {
        TextView customerNameText;
        ImageView expandCollapseIcon;
        ImageButton deleteCustomerButton;
        ImageButton whatsappShareButton;
        
        public HeaderViewHolder(@NonNull View itemView) {
            super(itemView);
            customerNameText = itemView.findViewById(R.id.text_customer_name);
            expandCollapseIcon = itemView.findViewById(R.id.image_expand_collapse);
            deleteCustomerButton = itemView.findViewById(R.id.btn_delete_customer);
            whatsappShareButton = itemView.findViewById(R.id.btn_whatsapp_share);
        }
    }
    
    // Resim için ViewHolder
    public static class ImageViewHolder extends RecyclerView.ViewHolder {
        TextView resimAdiText;
        TextView yuklemeDurumuText;
        TextView yukleyenText;
        TextView tarihText;
        ImageButton deleteButton;
        ImageView imagePreview;
        LinearLayout textContainer;
        
        public ImageViewHolder(@NonNull View itemView) {
            super(itemView);
            resimAdiText = itemView.findViewById(R.id.text_resim_adi);
            yuklemeDurumuText = itemView.findViewById(R.id.text_yukleme_durumu);
            yukleyenText = itemView.findViewById(R.id.text_yukleyen);
            tarihText = itemView.findViewById(R.id.text_tarih);
            deleteButton = itemView.findViewById(R.id.btn_delete_image);
            imagePreview = itemView.findViewById(R.id.image_preview);
            textContainer = itemView.findViewById(R.id.text_container);
        }
    }
    
    // Veri modelleri
    public static class CustomerHeader {
        public String customerName;
        public int imageCount;
        
        public CustomerHeader(String customerName, int imageCount) {
            this.customerName = customerName;
            this.imageCount = imageCount;
        }
    }
    
    public static class ImageItem {
        public int id;
        public String customerName;
        public String imagePath;
        public String uploader;
        public String date;
        
        public ImageItem(int id, String customerName, String imagePath, 
                String uploader, String date) {
            this.id = id;
            this.customerName = customerName;
            this.imagePath = imagePath;
            this.uploader = uploader;
            this.date = date;
        }
    }
    
    public LocalCustomerImagesAdapter(Context context, Cursor cursor, OnImageActionListener listener) {
        this.context = context;
        this.cursor = cursor;
        this.listener = listener;
        
        processCursor();
    }
    
    private void processCursor() {
        try {
            android.util.Log.d("LocalCustomerImagesAdapter", "processCursor başladı");
            
            if (items == null) {
                items = new ArrayList<>();
            }
            items.clear();
            
            if (expandedStates == null) {
                expandedStates = new HashMap<>();
            }
            
            if (customerGroups == null) {
                customerGroups = new HashMap<>();
            }
            customerGroups.clear();
            
            if (cursor == null) {
                android.util.Log.d("LocalCustomerImagesAdapter", "Cursor null, boş liste oluşturuluyor");
                return;
            }
            
            if (cursor.getCount() == 0) {
                android.util.Log.d("LocalCustomerImagesAdapter", "Cursor boş, boş liste oluşturuluyor");
                return;
            }
            
            try {
                // Cursor'u başa konumlandır
                if (!cursor.moveToFirst()) {
                    android.util.Log.w("LocalCustomerImagesAdapter", "Cursor moveToFirst başarısız");
                    return;
                }
                
                // Verileri müşteri adına göre gruplandır
                do {
                    try {
                        int idIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_ID);
                        int musteriAdiIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_MUSTERI_ADI);
                        int resimYoluIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_RESIM_YOLU);
                        int yukleyenIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_YUKLEYEN);
                        int tarihIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_TARIH);
                        
                        // Column index kontrolü
                        if (idIndex == -1 || musteriAdiIndex == -1 || resimYoluIndex == -1) {
                            android.util.Log.e("LocalCustomerImagesAdapter", "Gerekli column bulunamadı!");
                            continue;
                        }
                        
                        int id = cursor.getInt(idIndex);
                        String musteriAdi = cursor.getString(musteriAdiIndex);
                        String resimYolu = cursor.getString(resimYoluIndex);
                        String yukleyen = yukleyenIndex >= 0 ? cursor.getString(yukleyenIndex) : "Bilinmeyen";
                        String tarih = tarihIndex >= 0 ? cursor.getString(tarihIndex) : "Bilinmeyen";
                    
                        // Null kontrolü
                        if (musteriAdi == null || musteriAdi.trim().isEmpty()) {
                            android.util.Log.w("LocalCustomerImagesAdapter", "Müşteri adı boş, satır atlanıyor");
                            continue;
                        }
                        
                        if (resimYolu == null || resimYolu.trim().isEmpty()) {
                            android.util.Log.w("LocalCustomerImagesAdapter", "Resim yolu boş, satır atlanıyor");
                            continue;
                        }
                        
                        // Lokal adapter için basit constructor kullan
                        ImageItem imageItem = new ImageItem(id, musteriAdi, resimYolu, yukleyen, tarih);
                        
                        if (!customerGroups.containsKey(musteriAdi)) {
                            customerGroups.put(musteriAdi, new ArrayList<>());
                            // Müşterinin genişletme durumu henüz ayarlanmamışsa, varsayılan olarak false (kapalı) ayarla
                            if (!expandedStates.containsKey(musteriAdi)) {
                                expandedStates.put(musteriAdi, false);
                            }
                        }
                        
                        customerGroups.get(musteriAdi).add(imageItem);
                        
                    } catch (Exception e) {
                        android.util.Log.e("LocalCustomerImagesAdapter", "Cursor row işleme hatası: " + e.getMessage());
                        e.printStackTrace();
                    }
                    
                } while (cursor.moveToNext());
                
            } catch (Exception e) {
                android.util.Log.e("LocalCustomerImagesAdapter", "Cursor döngü hatası: " + e.getMessage());
                e.printStackTrace();
                return;
            }
            
            android.util.Log.d("LocalCustomerImagesAdapter", "Gruplandırma tamamlandı, " + customerGroups.size() + " müşteri grubu oluşturuldu");
            
            // Başlıkları ve resimleri listeye ekle
            for (Map.Entry<String, List<ImageItem>> entry : customerGroups.entrySet()) {
                try {
                    String customerName = entry.getKey();
                    List<ImageItem> images = entry.getValue();
                    
                    if (customerName == null || images == null) {
                        android.util.Log.w("LocalCustomerImagesAdapter", "Null müşteri veya resim listesi, atlanıyor");
                        continue;
                    }
                    
                    // Başlığı ekle
                    items.add(new CustomerHeader(customerName, images.size()));
                    
                    // Eğer bu müşteri genişletilmişse, resimlerini de ekle
                    if (expandedStates.getOrDefault(customerName, false)) {
                        items.addAll(images);
                    }
                    
                } catch (Exception e) {
                    android.util.Log.e("LocalCustomerImagesAdapter", "Müşteri grubu işleme hatası: " + e.getMessage());
                    e.printStackTrace();
                }
            }
            
            android.util.Log.d("LocalCustomerImagesAdapter", "processCursor tamamlandı, toplam " + items.size() + " item oluşturuldu");
            
        } catch (Exception e) {
            android.util.Log.e("LocalCustomerImagesAdapter", "processCursor genel hatası: " + e.getMessage());
            e.printStackTrace();
            // Hata durumunda boş liste oluştur
            if (items == null) {
                items = new ArrayList<>();
            } else {
                items.clear();
            }
        }
    }
    
    public void updateCursor(Cursor newCursor) {
        try {
            android.util.Log.d("LocalCustomerImagesAdapter", "updateCursor başladı");
            
            // Eski cursor'u güvenli şekilde kapat
            if (cursor != null && !cursor.isClosed()) {
                try {
                    cursor.close();
                    android.util.Log.d("LocalCustomerImagesAdapter", "Eski cursor kapatıldı");
                } catch (Exception e) {
                    android.util.Log.e("LocalCustomerImagesAdapter", "Eski cursor kapatma hatası: " + e.getMessage());
                }
            }
            
            // Yeni cursor'u ata
            cursor = newCursor;
            android.util.Log.d("LocalCustomerImagesAdapter", "Yeni cursor atandı");
            
            // Güvenli şekilde verileri işle
            try {
                processCursor();
                android.util.Log.d("LocalCustomerImagesAdapter", "processCursor başarılı");
            } catch (Exception e) {
                android.util.Log.e("LocalCustomerImagesAdapter", "processCursor hatası: " + e.getMessage());
                e.printStackTrace();
                // Hata durumunda boş liste oluştur
                if (items == null) {
                    items = new ArrayList<>();
                } else {
                    items.clear();
                }
            }
            
                            // Ana thread'de adapter'ı güncelle
                if (context instanceof android.app.Activity) {
                    ((android.app.Activity) context).runOnUiThread(() -> {
                        try {
                            android.util.Log.d("LocalCustomerImagesAdapter", "notifyDataSetChanged çağrılıyor (ana thread)");
                            notifyDataSetChanged();
                            android.util.Log.d("LocalCustomerImagesAdapter", "notifyDataSetChanged tamamlandı");
                            
                            // Zorla tüm ViewHolder'ları yenile
                            android.util.Log.d("LocalCustomerImagesAdapter", "notifyItemRangeChanged çağrılıyor - zorla yenileme");
                            notifyItemRangeChanged(0, getItemCount());
                            android.util.Log.d("LocalCustomerImagesAdapter", "notifyItemRangeChanged tamamlandı");
                            
                            // Ek olarak WhatsApp butonlarını da güncelle
                            android.util.Log.d("LocalCustomerImagesAdapter", "WhatsApp butonları da güncelleniyor...");
                            notifyItemRangeChanged(0, getItemCount(), "whatsapp_update");
                            android.util.Log.d("LocalCustomerImagesAdapter", "WhatsApp butonları güncellendi");
                        } catch (Exception e) {
                            android.util.Log.e("LocalCustomerImagesAdapter", "notifyDataSetChanged hatası: " + e.getMessage());
                            e.printStackTrace();
                        }
                    });
                } else {
                    try {
                        android.util.Log.d("LocalCustomerImagesAdapter", "notifyDataSetChanged çağrılıyor (direkt)");
                        notifyDataSetChanged();
                        
                        // Zorla tüm ViewHolder'ları yenile
                        android.util.Log.d("LocalCustomerImagesAdapter", "notifyItemRangeChanged çağrılıyor - zorla yenileme (direkt)");
                        notifyItemRangeChanged(0, getItemCount());
                        android.util.Log.d("LocalCustomerImagesAdapter", "notifyItemRangeChanged tamamlandı (direkt)");
                        
                        // Ek olarak WhatsApp butonlarını da güncelle
                        android.util.Log.d("LocalCustomerImagesAdapter", "WhatsApp butonları da güncelleniyor... (direkt)");
                        notifyItemRangeChanged(0, getItemCount(), "whatsapp_update");
                        android.util.Log.d("LocalCustomerImagesAdapter", "WhatsApp butonları güncellendi (direkt)");
                    } catch (Exception e) {
                        android.util.Log.e("LocalCustomerImagesAdapter", "Direct notifyDataSetChanged hatası: " + e.getMessage());
                        e.printStackTrace();
                    }
                }
            
            android.util.Log.d("LocalCustomerImagesAdapter", "updateCursor başarıyla tamamlandı");
            
        } catch (Exception e) {
            android.util.Log.e("LocalCustomerImagesAdapter", "updateCursor genel hatası: " + e.getMessage());
            e.printStackTrace();
            
            // Hata durumunda fallback
            try {
                if (items == null) {
                    items = new ArrayList<>();
                } else {
                    items.clear();
                }
                notifyDataSetChanged();
            } catch (Exception fallbackError) {
                android.util.Log.e("LocalCustomerImagesAdapter", "Fallback hatası: " + fallbackError.getMessage());
            }
        }
    }
    
    @Override
    public int getItemViewType(int position) {
        if (items.get(position) instanceof CustomerHeader) {
            return TYPE_HEADER;
        } else {
            return TYPE_IMAGE;
        }
    }
    
    @NonNull
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        if (viewType == TYPE_HEADER) {
            View view = LayoutInflater.from(context).inflate(R.layout.item_customer_header_local, parent, false);
            return new HeaderViewHolder(view);
        } else {
            View view = LayoutInflater.from(context).inflate(R.layout.item_saved_image, parent, false);
            return new ImageViewHolder(view);
        }
    }
    
    @Override
    public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
        if (holder.getItemViewType() == TYPE_HEADER) {
            bindHeaderViewHolder((HeaderViewHolder) holder, position);
        } else {
            bindImageViewHolder((ImageViewHolder) holder, position);
        }
    }
    
    private void bindHeaderViewHolder(HeaderViewHolder holder, int position) {
        try {
            android.util.Log.d("LocalCustomerImagesAdapter", "🔄 bindHeaderViewHolder çağrıldı - Position: " + position);
            
            if (position < 0 || position >= items.size()) {
                android.util.Log.e("LocalCustomerImagesAdapter", "bindHeaderViewHolder: Geçersiz position: " + position + ", items size: " + items.size());
                return;
            }
            
            Object item = items.get(position);
            if (!(item instanceof CustomerHeader)) {
                android.util.Log.e("LocalCustomerImagesAdapter", "bindHeaderViewHolder: Position " + position + " CustomerHeader değil: " + item.getClass().getSimpleName());
                return;
            }
            
            CustomerHeader header = (CustomerHeader) item;
            if (header == null || header.customerName == null) {
                android.util.Log.e("LocalCustomerImagesAdapter", "bindHeaderViewHolder: Header veya customerName null");
                return;
            }
            
            android.util.Log.d("LocalCustomerImagesAdapter", "🔄 Header bind ediliyor: " + header.customerName);
            
            String displayText = header.customerName + " (" + header.imageCount + ")";
            holder.customerNameText.setText(displayText);
            
            // Genişletme/daraltma durumuna göre ikonu ayarla
            boolean isExpanded = expandedStates.getOrDefault(header.customerName, false);
            holder.expandCollapseIcon.setImageResource(isExpanded 
                ? R.drawable.ic_expand_less 
                : R.drawable.ic_expand_more);
            
            // WhatsApp paylaşım durumunu kontrol et (son 5 dakika)
            android.util.Log.d("LocalCustomerImagesAdapter", "🔍 Buton durumu kontrol ediliyor: " + header.customerName);
            boolean isSharedRecently = isCustomerSharedRecently(header.customerName);
            
            if (isSharedRecently) {
                // Son 5 dakikada paylaşıldıysa butonu deaktif et ve görünümünü değiştir
                holder.whatsappShareButton.setEnabled(false);
                holder.whatsappShareButton.setAlpha(0.3f);
                holder.whatsappShareButton.setColorFilter(android.graphics.Color.GRAY, android.graphics.PorterDuff.Mode.SRC_IN);
                android.util.Log.d("LocalCustomerImagesAdapter", "🔴 WhatsApp butonu DEAKTİF edildi: " + header.customerName);
            } else {
                // 5 dakika geçmişse butonu aktif et
                holder.whatsappShareButton.setEnabled(true);
                holder.whatsappShareButton.setAlpha(1.0f);
                holder.whatsappShareButton.clearColorFilter();
                android.util.Log.d("LocalCustomerImagesAdapter", "✅ WhatsApp butonu AKTİF edildi: " + header.customerName);
            }
            
            // Ek kontrol - butonun gerçek durumunu logla
            android.util.Log.d("LocalCustomerImagesAdapter", "📊 Buton son durumu - Enabled: " + holder.whatsappShareButton.isEnabled() + 
                ", Alpha: " + holder.whatsappShareButton.getAlpha() + ", Müşteri: " + header.customerName);
            
            // CardView'a clickable ve background ekle
            holder.itemView.setClickable(true);
            holder.itemView.setFocusable(true);
            
            // Önceki listener'ları temizle
            holder.itemView.setOnClickListener(null);
            holder.customerNameText.setOnClickListener(null);
            holder.expandCollapseIcon.setOnClickListener(null);
            holder.deleteCustomerButton.setOnClickListener(null);
            holder.whatsappShareButton.setOnClickListener(null);
            
            // Tıklama dinleyicisi - tüm karta tıklama (genişlet/daralt)
            View.OnClickListener toggleListener = new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    try {
                        android.util.Log.d("LocalCustomerImagesAdapter", "Header'a tıklandı: " + header.customerName);
                        toggleGroup(header.customerName);
                    } catch (Exception e) {
                        android.util.Log.e("LocalCustomerImagesAdapter", "Toggle tıklama hatası: " + e.getMessage());
                        e.printStackTrace();
                    }
                }
            };
            
            holder.itemView.setOnClickListener(toggleListener);
            holder.customerNameText.setOnClickListener(toggleListener);
            holder.expandCollapseIcon.setOnClickListener(toggleListener);
            
            // Silme butonu tıklama dinleyicisi
            holder.deleteCustomerButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    try {
                        // Silme işlemi için onay iste
                        new MaterialAlertDialogBuilder(context)
                            .setTitle("Müşteri Resimlerini Sil")
                            .setMessage(header.customerName + " müşterisine ait tüm yerel resimleri silmek istediğinize emin misiniz?")
                            .setPositiveButton("Sil", (dialog, which) -> {
                                try {
                                    if (listener != null) {
                                        listener.onCustomerDelete(header.customerName);
                                    }
                                } catch (Exception e) {
                                    android.util.Log.e("LocalCustomerImagesAdapter", "Silme callback hatası: " + e.getMessage());
                                    e.printStackTrace();
                                }
                            })
                            .setNegativeButton("İptal", null)
                            .show();
                    } catch (Exception e) {
                        android.util.Log.e("LocalCustomerImagesAdapter", "Silme butonu tıklama hatası: " + e.getMessage());
                        e.printStackTrace();
                    }
                }
            });
            
            // WhatsApp paylaşım butonu tıklama dinleyicisi
            holder.whatsappShareButton.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    try {
                        // Önce paylaşım durumunu kontrol et (son 5 dakika)
                        if (isCustomerSharedRecently(header.customerName)) {
                            // Son 5 dakikada paylaşıldıysa engelle
                            android.util.Log.d("LocalCustomerImagesAdapter", "❌ Paylaşım ENGELLENDİ - müşteri son 5 dakikada paylaşılmış: " + header.customerName);
                            return;
                        }
                        
                        // Bu müşterinin resim yollarını topla
                        List<String> imagePaths = new ArrayList<>();
                        if (customerGroups.containsKey(header.customerName)) {
                            List<ImageItem> customerImages = customerGroups.get(header.customerName);
                            if (customerImages != null) {
                                for (ImageItem image : customerImages) {
                                    // Dosya var mı kontrol et
                                    if (image.imagePath != null && new java.io.File(image.imagePath).exists()) {
                                        imagePaths.add(image.imagePath);
                                    }
                                }
                            }
                        }
                        
                        if (imagePaths.isEmpty()) {
                            // Toast mesajını kaldırdık - sadece log
                            android.util.Log.w("LocalCustomerImagesAdapter", "Paylaşılabilir resim bulunamadı: " + header.customerName);
                            return;
                        }
                        
                        // WhatsApp paylaşım callback'ini çağır
                        android.util.Log.d("LocalCustomerImagesAdapter", "🚀 WhatsApp paylaşımı başlatılıyor: " + header.customerName);
                        if (listener != null) {
                            listener.onWhatsAppShare(header.customerName, imagePaths);
                            android.util.Log.d("LocalCustomerImagesAdapter", "✅ WhatsApp callback çağrıldı: " + header.customerName);
                        } else {
                            android.util.Log.e("LocalCustomerImagesAdapter", "❌ Listener null - callback çağrılamadı!");
                        }
                        
                    } catch (Exception e) {
                        android.util.Log.e("LocalCustomerImagesAdapter", "WhatsApp paylaşım hatası: " + e.getMessage());
                        e.printStackTrace();
                        // Toast mesajını kaldırdık - sadece log
                    }
                }
            });
            
        } catch (Exception e) {
            android.util.Log.e("LocalCustomerImagesAdapter", "bindHeaderViewHolder genel hatası: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    private void bindImageViewHolder(ImageViewHolder holder, int position) {
        ImageItem item = (ImageItem) items.get(position);
        
        File file = new File(item.imagePath);
        String dosyaAdi = file.getName();
        
        // Sadece dosya adını göster
        holder.resimAdiText.setText(dosyaAdi);
        
        // Resim önizlemesini yükle
        if (file.exists()) {
            // Dosya varsa thumbnail göster
            loadImageThumbnail(holder.imagePreview, item.imagePath);
            holder.imagePreview.setVisibility(View.VISIBLE);
            
            // Text container'ı image'ın yanına konumlandır
            RelativeLayout.LayoutParams textParams = (RelativeLayout.LayoutParams) holder.textContainer.getLayoutParams();
            textParams.addRule(RelativeLayout.END_OF, R.id.image_preview);
            textParams.addRule(RelativeLayout.ALIGN_PARENT_START, 0); // Kuralı kaldır
            holder.textContainer.setLayoutParams(textParams);
        } else {
            // Dosya silinmişse image preview'i gizle
            holder.imagePreview.setVisibility(View.GONE);
            
            // Text container'ı başa konumlandır
            RelativeLayout.LayoutParams textParams = (RelativeLayout.LayoutParams) holder.textContainer.getLayoutParams();
            textParams.addRule(RelativeLayout.END_OF, 0); // Kuralı kaldır
            textParams.addRule(RelativeLayout.ALIGN_PARENT_START, RelativeLayout.TRUE);
            holder.textContainer.setLayoutParams(textParams);
        }
        
        // Müşteri adını göster
        holder.yukleyenText.setText("Müşteri: " + item.customerName);
        holder.yukleyenText.setTextColor(context.getResources().getColor(android.R.color.darker_gray));
        
        // Yükleme durumu - Sadece lokal kayıt
        holder.yuklemeDurumuText.setText("📱 Yerel Kayıt");
        holder.yuklemeDurumuText.setTextColor(context.getResources().getColor(android.R.color.holo_blue_dark));
        holder.yuklemeDurumuText.setTypeface(null, android.graphics.Typeface.NORMAL);
        
        // Veritabanından cihaz sahibi bilgisini al
        String deviceOwner = item.uploader;
        
        // Cihaz sahibi bilgisi yoksa veya DeviceIdentifier formatındaysa veritabanından çek
        if (deviceOwner == null || deviceOwner.isEmpty() || deviceOwner.contains("(")) {
            // Cihaz kimliğini çıkarmaya çalış
            String deviceId = "";
            if (deviceOwner != null && deviceOwner.contains("(") && deviceOwner.contains(")")) {
                deviceId = deviceOwner.substring(deviceOwner.lastIndexOf("(") + 1, deviceOwner.lastIndexOf(")"));
            }
            
            // Veritabanından cihaz sahibi bilgisini çek
            DatabaseHelper dbHelper = new DatabaseHelper(context);
            String dbDeviceOwner = dbHelper.getCihazSahibi(deviceId);
            
            // Eğer veritabanından bir değer geldiyse kullan
            if (dbDeviceOwner != null && !dbDeviceOwner.isEmpty()) {
                deviceOwner = dbDeviceOwner;
            }
        }
        
        // Tarih ve kaydeden bilgisini göster
        if (item.date != null) {
            holder.tarihText.setText("Tarih: " + item.date + " | Kaydeden: " + deviceOwner);
            holder.tarihText.setVisibility(View.VISIBLE);
        } else {
            holder.tarihText.setText("Kaydeden: " + deviceOwner);
            holder.tarihText.setVisibility(View.VISIBLE);
        }
        
        // Silme butonuna tıklama işlevselliği
        holder.deleteButton.setOnClickListener(v -> {
            // Silme işlemini onayla
            new MaterialAlertDialogBuilder(context)
                .setTitle("Resmi Sil")
                .setMessage("Bu resmi silmek istediğinizden emin misiniz?")
                .setPositiveButton("Evet", (dialog, which) -> {
                    if (listener != null) {
                        listener.onImageDelete(item.id, item.imagePath);
                    }
                })
                .setNegativeButton("İptal", null)
                .show();
        });
        
        // Resim önizlemesine tıklama - resim görüntüleme
        holder.imagePreview.setOnClickListener(v -> {
            if (file.exists()) {
                if (listener != null) {
                    listener.onImageView(item.imagePath);
                }
            } else {
                // Dosya artık yok, kullanıcıya bilgi ver
                Toast.makeText(context, "Dosya bulunamadı.", Toast.LENGTH_SHORT).show();
            }
        });
        
        // Resme tıklama - eğer dosya hala mevcutsa
        holder.itemView.setOnClickListener(v -> {
            if (file.exists()) {
                if (listener != null) {
                    listener.onImageView(item.imagePath);
                }
            } else {
                // Dosya artık yok, kullanıcıya bilgi ver
                Toast.makeText(context, "Dosya bulunamadı.", Toast.LENGTH_SHORT).show();
            }
        });
    }
    
    /**
     * Resim thumbnail'ını yükler ve ImageView'a ayarlar
     */
    private void loadImageThumbnail(ImageView imageView, String imagePath) {
        try {
            File imageFile = new File(imagePath);
            if (imageFile.exists()) {
                // Küçük thumbnail oluştur (bellek tasarrufu için)
                BitmapFactory.Options options = new BitmapFactory.Options();
                options.inSampleSize = 4; // Resmi 1/4 boyutunda yükle
                options.inPreferredConfig = Bitmap.Config.RGB_565; // Daha az bellek kullan
                
                Bitmap bitmap = BitmapFactory.decodeFile(imagePath, options);
                if (bitmap != null) {
                    imageView.setImageBitmap(bitmap);
                    imageView.setScaleType(ImageView.ScaleType.CENTER_CROP);
                } else {
                    // Resim yüklenemedi, varsayılan icon göster
                    imageView.setImageResource(R.drawable.ic_image);
                    imageView.setScaleType(ImageView.ScaleType.CENTER);
                }
            } else {
                // Dosya yok, varsayılan icon göster
                imageView.setImageResource(R.drawable.ic_image);
                imageView.setScaleType(ImageView.ScaleType.CENTER);
            }
        } catch (Exception e) {
            // Hata durumunda varsayılan icon göster
            imageView.setImageResource(R.drawable.ic_image);
            imageView.setScaleType(ImageView.ScaleType.CENTER);
            android.util.Log.e("LocalCustomerImagesAdapter", "Resim yükleme hatası: " + e.getMessage());
        }
    }

    private void toggleGroup(String customerName) {
        try {
            android.util.Log.d("LocalCustomerImagesAdapter", "toggleGroup başladı: " + customerName);
            
            if (customerName == null || customerName.isEmpty()) {
                android.util.Log.w("LocalCustomerImagesAdapter", "toggleGroup: Müşteri adı boş");
                return;
            }
            
            if (expandedStates == null) {
                android.util.Log.w("LocalCustomerImagesAdapter", "toggleGroup: expandedStates null");
                expandedStates = new HashMap<>();
            }
            
            // Genişletme durumunu değiştir
            boolean isExpanded = expandedStates.getOrDefault(customerName, false);
            android.util.Log.d("LocalCustomerImagesAdapter", "Mevcut durum - " + customerName + ": " + isExpanded);
            
            // Eğer bu müşteri kapalıysa ve şimdi açılacaksa, diğer tüm açık müşterileri kapat
            if (!isExpanded) {
                android.util.Log.d("LocalCustomerImagesAdapter", "Müşteri açılıyor, diğerleri kapatılıyor");
                // Tüm müşterileri kapat
                for (String key : new HashMap<>(expandedStates).keySet()) {
                    expandedStates.put(key, false);
                }
                // Sadece seçilen müşteriyi aç
                expandedStates.put(customerName, true);
            } else {
                android.util.Log.d("LocalCustomerImagesAdapter", "Müşteri kapatılıyor");
                // Müşteri zaten açıksa, kapat
                expandedStates.put(customerName, false);
            }
            
            android.util.Log.d("LocalCustomerImagesAdapter", "expandedStates güncellendi, processCursor çağrılıyor");
            
            // Verileri yeniden oluştur
            try {
                processCursor();
                android.util.Log.d("LocalCustomerImagesAdapter", "processCursor tamamlandı");
            } catch (Exception e) {
                android.util.Log.e("LocalCustomerImagesAdapter", "processCursor hatası: " + e.getMessage());
                e.printStackTrace();
                return;
            }
            
            // Adaptörü ana thread'de yenile
            if (context instanceof android.app.Activity) {
                ((android.app.Activity) context).runOnUiThread(() -> {
                    try {
                        android.util.Log.d("LocalCustomerImagesAdapter", "notifyDataSetChanged çağrılıyor");
                        notifyDataSetChanged();
                        android.util.Log.d("LocalCustomerImagesAdapter", "notifyDataSetChanged tamamlandı");
                    } catch (Exception e) {
                        android.util.Log.e("LocalCustomerImagesAdapter", "notifyDataSetChanged hatası: " + e.getMessage());
                        e.printStackTrace();
                    }
                });
            } else {
                try {
                    notifyDataSetChanged();
                } catch (Exception e) {
                    android.util.Log.e("LocalCustomerImagesAdapter", "Direct notifyDataSetChanged hatası: " + e.getMessage());
                    e.printStackTrace();
                }
            }
            
            android.util.Log.d("LocalCustomerImagesAdapter", "toggleGroup başarıyla tamamlandı");
            
        } catch (Exception e) {
            android.util.Log.e("LocalCustomerImagesAdapter", "toggleGroup genel hatası: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    @Override
    public int getItemCount() {
        return items.size();
    }
    
    /**
     * Expanded states'i dışarıdan almak için getter metodu
     */
    public Map<String, Boolean> getExpandedStates() {
        return new HashMap<>(expandedStates);
    }
    
    /**
     * Expanded states'i dışarıdan ayarlamak için setter metodu
     */
    public void setExpandedStates(Map<String, Boolean> expandedStates) {
        if (expandedStates != null) {
            this.expandedStates = new HashMap<>(expandedStates);
            processCursor();
            notifyDataSetChanged();
        }
    }
    
    /**
     * WhatsApp buton durumlarını zorla güncelle
     */
    public void forceUpdateWhatsAppButtons() {
        try {
            android.util.Log.d("LocalCustomerImagesAdapter", "🔄 forceUpdateWhatsAppButtons çağrıldı");
            
            // Ana thread'de çalıştır
            if (context instanceof android.app.Activity) {
                ((android.app.Activity) context).runOnUiThread(() -> {
                    try {
                        // Tüm item'ları yeniden bind et
                        notifyItemRangeChanged(0, getItemCount(), "whatsapp_update");
                        android.util.Log.d("LocalCustomerImagesAdapter", "✅ WhatsApp butonları zorla güncellendi");
                    } catch (Exception e) {
                        android.util.Log.e("LocalCustomerImagesAdapter", "forceUpdateWhatsAppButtons hatası: " + e.getMessage());
                    }
                });
            } else {
                notifyItemRangeChanged(0, getItemCount(), "whatsapp_update");
                android.util.Log.d("LocalCustomerImagesAdapter", "✅ WhatsApp butonları zorla güncellendi (direkt)");
            }
        } catch (Exception e) {
            android.util.Log.e("LocalCustomerImagesAdapter", "forceUpdateWhatsAppButtons genel hatası: " + e.getMessage());
        }
    }
    
    /**
     * Müşterinin son 5 dakikada WhatsApp'ta paylaşılıp paylaşılmadığını kontrol eder
     */
    private boolean isCustomerSharedRecently(String customerName) {
        try {
            android.util.Log.d("LocalCustomerImagesAdapter", "=== WhatsApp Buton Kontrolü ===");
            android.util.Log.d("LocalCustomerImagesAdapter", "Ham müşteri adı: '" + customerName + "'");
            
            // Müşteri adını normalize et (boşlukları alt çizgi ile değiştir)
            String normalizedCustomerName = customerName.replace(" ", "_");
            android.util.Log.d("LocalCustomerImagesAdapter", "Normalize edilmiş müşteri adı: '" + normalizedCustomerName + "'");
            
            SharedPreferences prefs = context.getSharedPreferences("customer_images_prefs", Context.MODE_PRIVATE);
            String key = "whatsapp_shared_time_" + normalizedCustomerName;
            long lastSharedTime = prefs.getLong(key, 0);
            long currentTime = System.currentTimeMillis();
            long timeDifference = currentTime - lastSharedTime;
            
            // 5 dakika = 5 * 60 * 1000 = 300000 milisaniye
            boolean isRecentlyShared = timeDifference < 300000; // 5 dakika
            
            android.util.Log.d("LocalCustomerImagesAdapter", "SharedPreferences key: '" + key + "'");
            android.util.Log.d("LocalCustomerImagesAdapter", "Son paylaşım zamanı: " + lastSharedTime);
            android.util.Log.d("LocalCustomerImagesAdapter", "Şu anki zaman: " + currentTime);
            android.util.Log.d("LocalCustomerImagesAdapter", "Zaman farkı: " + timeDifference + " ms (" + (timeDifference / 1000) + " saniye)");
            android.util.Log.d("LocalCustomerImagesAdapter", "Son 5 dakikada paylaşıldı mı: " + isRecentlyShared);
            android.util.Log.d("LocalCustomerImagesAdapter", "Buton aktif olmalı mı: " + !isRecentlyShared);
            
            return isRecentlyShared;
        } catch (Exception e) {
            android.util.Log.e("LocalCustomerImagesAdapter", "Paylaşım süresi kontrol hatası: " + e.getMessage());
            return false;
        }
    }
} 