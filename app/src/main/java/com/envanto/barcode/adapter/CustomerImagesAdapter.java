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
import com.envanto.barcode.utils.NetworkUtils;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class CustomerImagesAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    private static final int TYPE_HEADER = 0;
    private static final int TYPE_IMAGE = 1;
    
    private Context context;
    private Cursor cursor;
    private List<Object> items = new ArrayList<>();
    private Map<String, Boolean> expandedStates = new HashMap<>();
    private OnImageActionListener listener;
    
    public interface OnImageActionListener {
        void onImageDelete(int id, String imagePath);
        void onImageView(String imagePath);
        void onCustomerDelete(String customerName);
    }
    
    // Header için ViewHolder
    public static class HeaderViewHolder extends RecyclerView.ViewHolder {
        TextView customerNameText;
        ImageView expandCollapseIcon;
        ImageButton deleteCustomerButton;
        
        public HeaderViewHolder(@NonNull View itemView) {
            super(itemView);
            customerNameText = itemView.findViewById(R.id.text_customer_name);
            expandCollapseIcon = itemView.findViewById(R.id.image_expand_collapse);
            deleteCustomerButton = itemView.findViewById(R.id.btn_delete_customer);
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
        public boolean isUploaded;
        
        public ImageItem(int id, String customerName, String imagePath, 
                String uploader, String date, boolean isUploaded) {
            this.id = id;
            this.customerName = customerName;
            this.imagePath = imagePath;
            this.uploader = uploader;
            this.date = date;
            this.isUploaded = isUploaded;
        }
        
        // Daha az parametreli constructor (uyumluluk için)
        public ImageItem(int id, String imagePath, String date, int isUploaded) {
            this.id = id;
            this.imagePath = imagePath;
            this.date = date;
            this.isUploaded = isUploaded == 1;
        }
    }
    
    public CustomerImagesAdapter(Context context, Cursor cursor, OnImageActionListener listener) {
        this.context = context;
        this.cursor = cursor;
        this.listener = listener;
        
        // İlk müşteriyi otomatik olarak genişletme özelliğini kaldırıyoruz
        // Tüm müşteriler kapalı olarak gelecek
        
        processCursor();
    }
    
    private void processCursor() {
        items.clear();
        // Önemli değişiklik: expandedStates'i temizlemiyoruz
        // böylece açık/kapalı durumları korunuyor
        
        if (cursor == null || cursor.getCount() == 0) {
            return;
        }
        
        Map<String, List<ImageItem>> customerGroups = new HashMap<>();
        
        // Verileri müşteri adına göre gruplandır
        cursor.moveToFirst();
        do {
            int idIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_ID);
            int musteriAdiIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_MUSTERI_ADI);
            int resimYoluIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_RESIM_YOLU);
            int yukleyenIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_YUKLEYEN);
            int tarihIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_TARIH);
            int yuklendiIndex = cursor.getColumnIndex(DatabaseHelper.COLUMN_YUKLENDI);
            
            int id = cursor.getInt(idIndex);
            String musteriAdi = cursor.getString(musteriAdiIndex);
            String resimYolu = cursor.getString(resimYoluIndex);
            String yukleyen = cursor.getString(yukleyenIndex);
            String tarih = cursor.getString(tarihIndex);
            boolean yuklendi = yuklendiIndex >= 0 && cursor.getInt(yuklendiIndex) == 1;
            
            // Tam parametreli constructor kullan
            ImageItem imageItem = new ImageItem(id, musteriAdi, resimYolu, yukleyen, tarih, yuklendi);
            
            if (!customerGroups.containsKey(musteriAdi)) {
                customerGroups.put(musteriAdi, new ArrayList<>());
                // Müşterinin genişletme durumu henüz ayarlanmamışsa, varsayılan olarak false (kapalı) ayarla
                if (!expandedStates.containsKey(musteriAdi)) {
                    expandedStates.put(musteriAdi, false);
                }
            }
            
            customerGroups.get(musteriAdi).add(imageItem);
            
        } while (cursor.moveToNext());
        
        // Başlıkları ve resimleri listeye ekle
        for (Map.Entry<String, List<ImageItem>> entry : customerGroups.entrySet()) {
            String customerName = entry.getKey();
            List<ImageItem> images = entry.getValue();
            
            // Başlığı ekle
            items.add(new CustomerHeader(customerName, images.size()));
            
            // Eğer bu müşteri genişletilmişse, resimlerini de ekle
            if (expandedStates.getOrDefault(customerName, false)) {
                items.addAll(images);
            }
        }
    }
    
    public void updateCursor(Cursor newCursor) {
        if (cursor != null) {
            cursor.close();
        }
        cursor = newCursor;
        processCursor();
        notifyDataSetChanged();
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
            View view = LayoutInflater.from(context).inflate(R.layout.item_customer_header, parent, false);
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
        CustomerHeader header = (CustomerHeader) items.get(position);
        String displayText = header.customerName + " (" + header.imageCount + ")";
        holder.customerNameText.setText(displayText);
        
        // Genişletme/daraltma durumuna göre ikonu ayarla
        boolean isExpanded = expandedStates.getOrDefault(header.customerName, false);
        holder.expandCollapseIcon.setImageResource(isExpanded 
            ? R.drawable.ic_expand_less 
            : R.drawable.ic_expand_more);
        
        // Tıklama dinleyicisi - tüm karta tıklama
        holder.itemView.setOnClickListener(v -> {
            toggleGroup(header.customerName);
        });
        
        // Ayrıca icon'a tıklama için özel olarak işleyici ekleyelim
        holder.expandCollapseIcon.setOnClickListener(v -> {
            toggleGroup(header.customerName);
        });
        
        // Silme butonu tıklama dinleyicisi
        holder.deleteCustomerButton.setOnClickListener(v -> {
            // Silme işlemi için onay iste
            new MaterialAlertDialogBuilder(context)
                .setTitle("Müşteri Resimlerini Sil")
                .setMessage(header.customerName + " müşterisine ait yüklenmiş resimleri silmek istediğinize emin misiniz?\n\nNot: Yüklenmeyi bekleyen resimler silinmeyecektir.")
                .setPositiveButton("Sil", (dialog, which) -> {
                    if (listener != null) {
                        listener.onCustomerDelete(header.customerName);
                    }
                })
                .setNegativeButton("İptal", null)
                .show();
        });
    }
    
    private void bindImageViewHolder(ImageViewHolder holder, int position) {
        ImageItem item = (ImageItem) items.get(position);
        
        File file = new File(item.imagePath);
        String dosyaAdi = file.getName();
        
        // Sadece dosya adını göster, ek bilgi ekleme
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
            // Dosya sunucuya yüklenmiş ve silinmişse image preview'i gizle
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
        
        // Yükleme durumunu göster
        if (item.isUploaded) {
            // Sunucuya yüklenmiş dosya - yeşil renk ve tik işareti
            holder.yuklemeDurumuText.setText("✅ SUNUCUYA YÜKLENDİ");
            holder.yuklemeDurumuText.setTextColor(context.getResources().getColor(android.R.color.holo_green_dark));
            holder.yuklemeDurumuText.setTypeface(null, android.graphics.Typeface.BOLD);
        } else {
            // Network durumuna göre durum belirle
            boolean isWifiAvailable = NetworkUtils.isWifiConnected(context);
            boolean isNetworkAvailable = NetworkUtils.isNetworkAvailable(context);
            
            // Kullanıcının bağlantı tercihini kontrol et
            android.content.SharedPreferences preferences = context.getSharedPreferences("envanto_barcode_prefs", Context.MODE_PRIVATE);
            boolean wifiOnly = preferences.getBoolean("wifi_only", true);
            
            if (!isNetworkAvailable) {
                // Hiç internet yok
                holder.yuklemeDurumuText.setText("⚠️ İnternet Bekleniyor");
                holder.yuklemeDurumuText.setTextColor(context.getResources().getColor(android.R.color.holo_red_dark));
            } else if (wifiOnly && !isWifiAvailable) {
                // WiFi-only seçili ama WiFi yok (mobil veri olsa da beklemeli)
                holder.yuklemeDurumuText.setText("📶 WiFi Bekleniyor");
                holder.yuklemeDurumuText.setTextColor(context.getResources().getColor(android.R.color.holo_orange_dark));
            } else {
                // Yükleme yapılabilir durumda (WiFi var VEYA tüm bağlantılar seçili ve internet var)
                holder.yuklemeDurumuText.setText("🔄 Yükleme Sırasında");
                holder.yuklemeDurumuText.setTextColor(context.getResources().getColor(android.R.color.holo_blue_dark));
            }
        }
        
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
            com.envanto.barcode.database.DatabaseHelper dbHelper = new com.envanto.barcode.database.DatabaseHelper(context);
            String dbDeviceOwner = dbHelper.getCihazSahibi(deviceId);
            
            // Eğer veritabanından bir değer geldiyse kullan
            if (dbDeviceOwner != null && !dbDeviceOwner.isEmpty()) {
                deviceOwner = dbDeviceOwner;
            }
        }
        
        // Tarih ve yükleyen bilgisini göster
        if (item.date != null) {
            holder.tarihText.setText("Tarih: " + item.date + " | Yükleyen: " + deviceOwner);
            holder.tarihText.setVisibility(View.VISIBLE);
        } else {
            holder.tarihText.setText("Yükleyen: " + deviceOwner);
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
                Toast.makeText(context, "Dosya sunucuya yüklenmiş ve yerel depolamadan silinmiş.", Toast.LENGTH_SHORT).show();
            }
        });
        
        // Resme tıklama - eğer dosya hala mevcutsa (eski davranış korundu)
        holder.itemView.setOnClickListener(v -> {
            if (file.exists()) {
                if (listener != null) {
                    listener.onImageView(item.imagePath);
                }
            } else {
                // Dosya artık yok, kullanıcıya bilgi ver
                Toast.makeText(context, "Dosya sunucuya yüklenmiş ve yerel depolamadan silinmiş.", Toast.LENGTH_SHORT).show();
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
            android.util.Log.e("CustomerImagesAdapter", "Resim yükleme hatası: " + e.getMessage());
        }
    }
    
    private void toggleGroup(String customerName) {
        // Genişletme durumunu değiştir
        boolean isExpanded = expandedStates.getOrDefault(customerName, false);
        
        // Eğer bu müşteri kapalıysa ve şimdi açılacaksa, diğer tüm açık müşterileri kapat
        if (!isExpanded) {
            // Tüm müşterileri kapat
            for (String key : expandedStates.keySet()) {
                expandedStates.put(key, false);
            }
            // Sadece seçilen müşteriyi aç
            expandedStates.put(customerName, true);
        } else {
            // Müşteri zaten açıksa, kapat
            expandedStates.put(customerName, false);
        }
        
        // Verileri yeniden oluştur ve adaptörü yenile
        processCursor();
        notifyDataSetChanged();
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
}