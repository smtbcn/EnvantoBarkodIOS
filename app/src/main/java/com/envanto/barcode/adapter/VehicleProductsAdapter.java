package com.envanto.barcode.adapter;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.CheckBox;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.envanto.barcode.R;
import com.envanto.barcode.api.VehicleProduct;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class VehicleProductsAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
    
    private static final int TYPE_HEADER = 0;
    private static final int TYPE_PRODUCT = 1;
    
    private List<Object> items = new ArrayList<>();
    private Map<String, Boolean> expandedStates = new HashMap<>();
    private List<VehicleProduct> allProducts = new ArrayList<>();
    private Set<String> selectedCustomers = new HashSet<>();
    private OnSelectionChangeListener selectionChangeListener;
    private OnReturnToDepotListener returnToDepotListener;
    
    // Seçim değişikliği callback interface
    public interface OnSelectionChangeListener {
        void onSelectionChanged(int selectedCount);
    }
    
    // Depoya geri bırakma callback interface
    public interface OnReturnToDepotListener {
        void onReturnToDepot(VehicleProduct product);
    }
    
    // Header için ViewHolder
    public static class HeaderViewHolder extends RecyclerView.ViewHolder {
        TextView customerNameText;
        TextView productCountText;
        CheckBox customerCheckBox;
        ImageView expandCollapseIcon;
        
        HeaderViewHolder(View itemView) {
            super(itemView);
            customerNameText = itemView.findViewById(R.id.text_customer_name);
            productCountText = itemView.findViewById(R.id.text_product_count);
            customerCheckBox = itemView.findViewById(R.id.checkbox_customer_select);
            expandCollapseIcon = itemView.findViewById(R.id.image_expand_collapse);
        }
    }

    // Ürün için ViewHolder
    static class ProductViewHolder extends RecyclerView.ViewHolder {
        TextView musteriAdiText;
        TextView urunAdiText;
        TextView urunAdetText;
        TextView depoAktaranText;
        TextView depoAktaranTarihiText;
        TextView mevcutDepoText;
        com.google.android.material.button.MaterialButton btnReturnToDepot;
        
        ProductViewHolder(View itemView) {
            super(itemView);
            musteriAdiText = itemView.findViewById(R.id.tv_musteri_adi);
            urunAdiText = itemView.findViewById(R.id.tv_urun_adi);
            urunAdetText = itemView.findViewById(R.id.tv_urun_adet);
            depoAktaranText = itemView.findViewById(R.id.tv_depo_aktaran);
            depoAktaranTarihiText = itemView.findViewById(R.id.tv_depo_aktaran_tarihi);
            mevcutDepoText = itemView.findViewById(R.id.tv_mevcut_depo);
            btnReturnToDepot = itemView.findViewById(R.id.btn_return_to_depot);
        }
    }

    // Veri modelleri
    public static class CustomerHeader {
        public String customerName;
        public int productCount;
        
        public CustomerHeader(String customerName, int productCount) {
            this.customerName = customerName;
            this.productCount = productCount;
        }
    }

    public VehicleProductsAdapter(List<VehicleProduct> products) {
        processProducts(products);
    }
    
    public void setOnSelectionChangeListener(OnSelectionChangeListener listener) {
        this.selectionChangeListener = listener;
    }
    
    public void setOnReturnToDepotListener(OnReturnToDepotListener listener) {
        this.returnToDepotListener = listener;
    }
    
    private void processProducts(List<VehicleProduct> products) {
        items.clear();
        
        if (products == null || products.isEmpty()) {
            allProducts.clear();
            return;
        }
        
        // Tüm ürünleri sakla
        allProducts = new ArrayList<>(products);
        
        // Müşteri adına göre gruplandır
        Map<String, List<VehicleProduct>> customerGroups = new HashMap<>();
        
        for (VehicleProduct product : products) {
            String customerName = product.getMusteri_adi();
            if (!customerGroups.containsKey(customerName)) {
                customerGroups.put(customerName, new ArrayList<>());
                // Müşterinin genişletme durumu henüz ayarlanmamışsa, varsayılan olarak false (kapalı) ayarla
                if (!expandedStates.containsKey(customerName)) {
                    expandedStates.put(customerName, false);
                }
            }
            customerGroups.get(customerName).add(product);
        }
        
        // Başlıkları ve ürünleri listeye ekle
        for (Map.Entry<String, List<VehicleProduct>> entry : customerGroups.entrySet()) {
            String customerName = entry.getKey();
            List<VehicleProduct> customerProducts = entry.getValue();
            
            // Başlığı ekle
            items.add(new CustomerHeader(customerName, customerProducts.size()));
            
            // Eğer bu müşteri genişletilmişse, ürünlerini de ekle
            if (expandedStates.getOrDefault(customerName, false)) {
                items.addAll(customerProducts);
            }
        }
    }

    @Override
    public int getItemViewType(int position) {
        Object item = items.get(position);
        if (item instanceof CustomerHeader) {
            return TYPE_HEADER;
        } else {
            return TYPE_PRODUCT;
        }
    }

    @NonNull
    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        if (viewType == TYPE_HEADER) {
            View view = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_vehicle_customer_header, parent, false);
            return new HeaderViewHolder(view);
        } else {
            View view = LayoutInflater.from(parent.getContext())
                    .inflate(R.layout.item_vehicle_product, parent, false);
            return new ProductViewHolder(view);
        }
    }
    
    @Override
    public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
        if (holder instanceof HeaderViewHolder) {
            bindHeaderViewHolder((HeaderViewHolder) holder, position);
        } else if (holder instanceof ProductViewHolder) {
            bindProductViewHolder((ProductViewHolder) holder, position);
        }
    }

    private void bindHeaderViewHolder(HeaderViewHolder holder, int position) {
        CustomerHeader header = (CustomerHeader) items.get(position);
        String customerName = header.customerName;
        
        holder.customerNameText.setText(customerName);
        holder.productCountText.setText(header.productCount + " ürün");
        
        // Checkbox durumu
        boolean isSelected = selectedCustomers.contains(customerName);
        holder.customerCheckBox.setChecked(isSelected);
        
        // Genişletme ikonu durumu
        boolean isExpanded = expandedStates.getOrDefault(customerName, false);
        holder.expandCollapseIcon.setImageResource(
            isExpanded ? R.drawable.ic_expand_less : R.drawable.ic_expand_more
        );
        
        // Checkbox click listener
        holder.customerCheckBox.setOnClickListener(v -> {
            boolean checked = holder.customerCheckBox.isChecked();
            if (checked) {
                selectedCustomers.add(customerName);
            } else {
                selectedCustomers.remove(customerName);
            }
            
            // Seçim değişikliği callback'ini çağır
            if (selectionChangeListener != null) {
                selectionChangeListener.onSelectionChanged(selectedCustomers.size());
            }
        });
        
        // Tıklama işlemi (sadece expand/collapse için)
        holder.itemView.setOnClickListener(v -> toggleGroup(customerName));
        holder.expandCollapseIcon.setOnClickListener(v -> toggleGroup(customerName));
    }
    
    private void bindProductViewHolder(ProductViewHolder holder, int position) {
        VehicleProduct product = (VehicleProduct) items.get(position);
        
        holder.musteriAdiText.setText(product.getMusteri_adi());
        holder.urunAdiText.setText(product.getUrun_adi());
        holder.urunAdetText.setText(String.valueOf(product.getUrun_adet()));
        holder.depoAktaranText.setText(product.getDepo_aktaran());
        holder.depoAktaranTarihiText.setText(product.getDepo_aktaran_tarihi());
        holder.mevcutDepoText.setText(product.getMevcut_depo());
        
        // Depoya geri bırakma butonu click listener
        holder.btnReturnToDepot.setOnClickListener(v -> {
            if (returnToDepotListener != null) {
                returnToDepotListener.onReturnToDepot(product);
            }
        });
    }
    
    private void toggleGroup(String customerName) {
        boolean wasExpanded = expandedStates.getOrDefault(customerName, false);
        expandedStates.put(customerName, !wasExpanded);
        
        // Grupları yeniden oluştur ancak expanded states'i koru
        processProducts(allProducts);
        notifyDataSetChanged();
    }

    @Override
    public int getItemCount() {
        return items.size();
    }
    
    public void updateData(List<VehicleProduct> newProducts) {
        // Yeni veri ile mevcut müşteri listesini karşılaştır
        if (newProducts != null && !newProducts.isEmpty()) {
            Set<String> newCustomers = new HashSet<>();
            for (VehicleProduct product : newProducts) {
                newCustomers.add(product.getMusteri_adi());
            }
            
            // Artık mevcut olmayan müşterileri seçimlerden ve expanded durumlardan kaldır
            selectedCustomers.retainAll(newCustomers);
            expandedStates.keySet().retainAll(newCustomers);
        } else {
            // Veri boşsa tüm seçimleri ve durumları temizle
            selectedCustomers.clear();
            expandedStates.clear();
        }
        
        processProducts(newProducts);
        notifyDataSetChanged();
        
        // Seçim değişikliği callback'ini çağır
        if (selectionChangeListener != null) {
            selectionChangeListener.onSelectionChanged(selectedCustomers.size());
        }
    }
    
    /**
     * Seçili müşteri isimlerini döndürür
     */
    public Set<String> getSelectedCustomers() {
        return new HashSet<>(selectedCustomers);
    }
    
    /**
     * Tüm seçimleri temizler
     */
    public void clearSelections() {
        selectedCustomers.clear();
        notifyDataSetChanged();
        
        // Seçim değişikliği callback'ini çağır
        if (selectionChangeListener != null) {
            selectionChangeListener.onSelectionChanged(0);
        }
    }
    
    /**
     * Seçili müşteri sayısını döndürür
     */
    public int getSelectedCount() {
        return selectedCustomers.size();
    }
} 