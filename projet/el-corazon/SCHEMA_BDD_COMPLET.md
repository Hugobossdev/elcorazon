# 📊 Schéma Complet de la Base de Données - El Corazón FastGo

## 🎯 Vue d'ensemble

Ce document présente le schéma complet de la base de données Supabase pour le système El Corazón FastGo, qui supporte trois applications :
- **🛍️ elcora_fast** : Application client
- **🚗 elcora_dely** : Application livreur
- **⚙️ admin** : Panel d'administration

---

## 📚 Table des Matières

1. [Tables Principales](#tables-principales)
2. [Système d'Authentification et Utilisateurs](#système-dauthentification-et-utilisateurs)
3. [Système de Menu et Produits](#système-de-menu-et-produits)
4. [Système de Commandes](#système-de-commandes)
5. [Système de Livraison](#système-de-livraison)
6. [Système de Paiements](#système-de-paiements)
7. [Système de Gamification et Fidélité](#système-de-gamification-et-fidélité)
8. [Système Social](#système-social)
9. [Système de Notifications](#système-de-notifications)
10. [Système de Promotions](#système-de-promotions)
11. [Système d'Analytics](#système-danalytics)
12. [Relations et Diagramme ERD](#relations-et-diagramme-erd)

---

## 📊 Tables Principales

### 1. Système d'Authentification et Utilisateurs

#### `users` - Table centrale des utilisateurs
```sql
CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    auth_user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('client', 'admin', 'delivery')),
    profile_image TEXT,
    loyalty_points INTEGER DEFAULT 0,
    badges TEXT[] DEFAULT '{}',
    is_online BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Champs spécifiques aux livreurs (à migrer vers table drivers)
    profile_photo_url TEXT,
    license_number TEXT,
    id_number TEXT,
    vehicle_type TEXT,
    vehicle_number TEXT,
    license_photo_url TEXT,
    id_card_photo_url TEXT,
    vehicle_photo_url TEXT,
    verification_status TEXT DEFAULT 'pending',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Index :**
- `idx_users_auth_user_id` : Recherche rapide par auth_user_id
- `idx_users_role` : Filtrage par rôle
- `idx_users_is_online` : État en ligne
- `idx_users_loyalty_points` : Tri par points de fidélité

---

#### `drivers` - Profils des livreurs
```sql
CREATE TABLE drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    
    -- Informations de vérification
    profile_photo_url TEXT,
    license_number TEXT,
    id_number TEXT,
    vehicle_type TEXT,
    vehicle_number TEXT,
    license_photo_url TEXT,
    id_card_photo_url TEXT,
    vehicle_photo_url TEXT,
    verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    verification_notes TEXT,
    verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    
    -- Statistiques
    total_deliveries INTEGER DEFAULT 0,
    completed_deliveries INTEGER DEFAULT 0,
    rating DECIMAL(3,2) DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
    total_ratings INTEGER DEFAULT 0,
    total_earnings DECIMAL(10,2) DEFAULT 0.0,
    
    -- Disponibilité
    is_available BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) DEFAULT 'offline' CHECK (status IN ('available', 'busy', 'on_delivery', 'offline')),
    current_location_latitude DECIMAL(10,8),
    current_location_longitude DECIMAL(11,8),
    last_location_update TIMESTAMP WITH TIME ZONE,
    last_online TIMESTAMP WITH TIME ZONE,
    
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Index :**
- `idx_drivers_user_id` : Lien avec users
- `idx_drivers_verification_status` : Filtrage par statut
- `idx_drivers_is_available` : Livreurs disponibles
- `idx_drivers_status` : Statut actuel
- `idx_drivers_rating` : Tri par note
- `idx_drivers_location` : Recherche géographique

**Vues associées :**
- `available_drivers_view` : Livreurs disponibles avec infos utilisateur
- `pending_verification_drivers_view` : Livreurs en attente de vérification
- `driver_stats_view` : Statistiques complètes des livreurs

---

#### `addresses` - Adresses utilisateurs
```sql
CREATE TABLE addresses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    city TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    type TEXT NOT NULL DEFAULT 'other',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

#### `admin_roles` - Rôles administrateurs
```sql
CREATE TABLE admin_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    permissions JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `user_admin_roles` - Liaison utilisateurs ↔ rôles admin
```sql
CREATE TABLE user_admin_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES admin_roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, role_id)
);
```

---

### 2. Système de Menu et Produits

#### `menu_categories` - Catégories de menu
```sql
CREATE TABLE menu_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    emoji TEXT NOT NULL,
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Données initiales :**
- 🍔 Burgers
- 🍕 Pizzas
- 🥤 Boissons
- 🍰 Desserts
- 🍟 Accompagnements
- 🥗 Salades
- 🍽️ Menus
- ⭐ Spécialités

---

#### `menu_items` - Éléments de menu
```sql
CREATE TABLE menu_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    category_id UUID NOT NULL REFERENCES menu_categories(id) ON DELETE CASCADE,
    image_url TEXT,
    
    -- Caractéristiques
    is_popular BOOLEAN DEFAULT FALSE,
    is_vegetarian BOOLEAN DEFAULT FALSE,
    is_vegan BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    available_quantity INTEGER DEFAULT 100,
    vip_exclusive BOOLEAN DEFAULT FALSE,
    
    -- Informations nutritionnelles
    ingredients TEXT[] DEFAULT '{}',
    calories INTEGER DEFAULT 0,
    allergens TEXT[] DEFAULT '{}',
    
    -- Préparation
    preparation_time INTEGER DEFAULT 15, -- en minutes
    
    -- Évaluations
    rating DECIMAL(3,2) DEFAULT 0.0,
    review_count INTEGER DEFAULT 0,
    
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Index :**
- `idx_menu_items_category_id` : Filtrage par catégorie
- `idx_menu_items_is_available` : Articles disponibles
- `idx_menu_items_is_popular` : Articles populaires
- `idx_menu_items_price` : Tri par prix
- `idx_menu_items_rating` : Tri par note

---

#### `customization_options` - Options de personnalisation
```sql
CREATE TABLE customization_options (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN (
        'ingredient', 'sauce', 'size', 'cooking', 'extra', 
        'shape', 'flavor', 'filling', 'decoration', 'tiers', 'icing', 'dietary'
    )),
    price_modifier DECIMAL(10,2) DEFAULT 0.0,
    is_default BOOLEAN DEFAULT FALSE,
    max_quantity INTEGER DEFAULT 1,
    description TEXT,
    image_url TEXT,
    allergens TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `menu_item_customizations` - Liaison menu ↔ options
```sql
CREATE TABLE menu_item_customizations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    customization_option_id UUID NOT NULL REFERENCES customization_options(id) ON DELETE CASCADE,
    is_required BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(menu_item_id, customization_option_id)
);
```

---

#### `product_reviews` - Avis sur les produits
```sql
CREATE TABLE product_reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    rating DECIMAL(3,2) NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title TEXT,
    comment TEXT NOT NULL,
    photos TEXT[] DEFAULT '{}',
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(menu_item_id, user_id)
);
```

**Triggers :**
- Mise à jour automatique de `menu_items.rating` et `menu_items.review_count`

---

#### `inventory_items` - Gestion de l'inventaire
```sql
CREATE TABLE inventory_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    current_stock DECIMAL(10,2) NOT NULL DEFAULT 0,
    minimum_stock DECIMAL(10,2) NOT NULL DEFAULT 0,
    unit TEXT NOT NULL, -- 'kg', 'liters', 'pieces', etc.
    unit_price DECIMAL(10,2) NOT NULL,
    last_restock_date TIMESTAMP WITH TIME ZONE,
    expiry_date TIMESTAMP WITH TIME ZONE,
    supplier TEXT,
    location TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

### 3. Système de Commandes

#### `orders` - Commandes
```sql
CREATE TABLE orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delivery_person_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Statut
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'confirmed', 'preparing', 'ready', 
        'picked_up', 'on_the_way', 'delivered', 'cancelled'
    )),
    
    -- Montants
    subtotal DECIMAL(10,2) NOT NULL,
    delivery_fee DECIMAL(10,2) DEFAULT 5.00,
    discount DECIMAL(10,2) DEFAULT 0.00,
    total DECIMAL(10,2) NOT NULL,
    
    -- Livraison
    delivery_address TEXT NOT NULL,
    delivery_latitude DECIMAL(10,8),
    delivery_longitude DECIMAL(11,8),
    delivery_notes TEXT,
    special_instructions TEXT,
    
    -- Paiement
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'card', 'wallet', 'mobile_money')),
    payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN (
        'pending', 'processing', 'completed', 'failed', 'refunded'
    )),
    payment_transaction_id TEXT,
    
    -- Code promo
    promo_code TEXT,
    
    -- Timing
    order_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    estimated_delivery_time TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    
    -- Commandes groupées
    is_group_order BOOLEAN DEFAULT FALSE,
    group_id UUID,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Index :**
- `idx_orders_user_id` : Commandes par utilisateur
- `idx_orders_delivery_person_id` : Commandes par livreur
- `idx_orders_status` : Filtrage par statut
- `idx_orders_created_at` : Tri chronologique
- `idx_orders_is_group_order` : Commandes groupées
- `idx_orders_group_id` : Groupes de commandes

---

#### `order_items` - Éléments de commande
```sql
CREATE TABLE order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    menu_item_name TEXT NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    menu_item_image TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    customizations JSONB DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Index :**
- `idx_order_items_order_id` : Articles par commande
- `idx_order_items_menu_item_id` : Statistiques par article

---

#### `order_status_updates` - Historique des statuts
```sql
CREATE TABLE order_status_updates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

#### `order_tracking` - Suivi des commandes
```sql
CREATE TABLE order_tracking (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_tracking BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(order_id, user_id)
);
```

---

#### `user_carts` - Paniers utilisateurs
```sql
CREATE TABLE user_carts (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    delivery_fee DECIMAL(10,2) DEFAULT 500.0,
    discount DECIMAL(10,2) DEFAULT 0.0,
    promo_code TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `user_cart_items` - Articles du panier
```sql
CREATE TABLE user_cart_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    menu_item_id TEXT NOT NULL,
    name TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    image_url TEXT,
    customizations JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

### 4. Système de Livraison

#### `delivery_locations` - Positions en temps réel
```sql
CREATE TABLE delivery_locations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    delivery_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    accuracy DECIMAL(8,2),
    speed DECIMAL(8,2),
    heading DECIMAL(8,2),
    altitude DECIMAL(8,2),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Index :**
- `idx_delivery_locations_order_id` : Positions par commande
- `idx_delivery_locations_delivery_id` : Positions par livreur
- `idx_delivery_locations_timestamp` : Tri chronologique

---

#### `active_deliveries` - Livraisons en cours
```sql
CREATE TABLE active_deliveries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    delivery_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN (
        'assigned', 'accepted', 'picked_up', 'on_the_way', 'delivered'
    )),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,
    picked_up_at TIMESTAMP WITH TIME ZONE,
    started_delivery_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Vues associées :**
- `delivery_stats` : Statistiques de livraison
- `active_orders_view` : Vue complète des commandes en cours

---

### 5. Système de Paiements

#### `group_payments` - Paiements groupés
```sql
CREATE TABLE group_payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID REFERENCES social_groups(id) ON DELETE SET NULL,
    order_id UUID NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'in_progress', 'completed', 'cancelled'
    )),
    initiated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `group_payment_participants` - Participants aux paiements groupés
```sql
CREATE TABLE group_payment_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_payment_id UUID NOT NULL REFERENCES group_payments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    operator TEXT,
    amount DECIMAL(10,2) NOT NULL,
    paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'processing', 'paid', 'failed', 'cancelled'
    )),
    transaction_id TEXT,
    payment_result JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

### 6. Système de Gamification et Fidélité

#### `achievements` - Succès à débloquer
```sql
CREATE TABLE achievements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    icon TEXT NOT NULL,
    points_reward INTEGER DEFAULT 0,
    badge_reward TEXT,
    condition_type TEXT NOT NULL CHECK (condition_type IN (
        'orders_count', 'total_spent', 'streak_days', 'category_orders', 'special'
    )),
    condition_value INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `user_achievements` - Succès des utilisateurs
```sql
CREATE TABLE user_achievements (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0,
    is_unlocked BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, achievement_id)
);
```

---

#### `challenges` - Défis
```sql
CREATE TABLE challenges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    challenge_type TEXT NOT NULL CHECK (challenge_type IN (
        'daily', 'weekly', 'monthly', 'special'
    )),
    target_value INTEGER NOT NULL,
    reward_points INTEGER DEFAULT 0,
    reward_discount DECIMAL(5,2) DEFAULT 0.0,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `user_challenges` - Participation aux défis
```sql
CREATE TABLE user_challenges (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, challenge_id)
);
```

---

#### `badges` - Badges de fidélité
```sql
CREATE TABLE badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    icon TEXT NOT NULL DEFAULT '🏅',
    points_required INTEGER DEFAULT 0,
    criteria TEXT NOT NULL DEFAULT 'points',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `user_badges` - Badges des utilisateurs
```sql
CREATE TABLE user_badges (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0,
    is_unlocked BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, badge_id)
);
```

---

#### `loyalty_rewards` - Récompenses de fidélité
```sql
CREATE TABLE loyalty_rewards (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    cost INTEGER NOT NULL,
    reward_type TEXT NOT NULL CHECK (reward_type IN (
        'discount', 'free_item', 'free_delivery', 'cashback', 'exclusive_offer'
    )),
    value DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `loyalty_transactions` - Transactions de points
```sql
CREATE TABLE loyalty_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN (
        'earn', 'redeem', 'bonus', 'adjustment', 'expiration'
    )),
    points INTEGER NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `reward_redemptions` - Échanges de récompenses
```sql
CREATE TABLE reward_redemptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_id TEXT NOT NULL,
    cost INTEGER NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

#### `subscriptions` - Abonnements VIP et repas
```sql
CREATE TABLE subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subscription_type TEXT NOT NULL CHECK (subscription_type IN ('weekly', 'monthly', 'vip')),
    plan_name TEXT,
    meals_per_week INTEGER DEFAULT 0,
    price_per_meal DECIMAL(10,2) DEFAULT 0.0,
    monthly_price DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
        'active', 'paused', 'cancelled', 'expired'
    )),
    current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    meals_used_this_period INTEGER DEFAULT 0,
    auto_renew BOOLEAN DEFAULT TRUE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `subscription_orders` - Commandes d'abonnement
```sql
CREATE TABLE subscription_orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    meal_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(subscription_id, order_id)
);
```

---

### 7. Système Social

#### `social_groups` - Groupes sociaux
```sql
CREATE TABLE social_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    group_type TEXT NOT NULL CHECK (group_type IN (
        'family', 'friends', 'work', 'neighborhood', 'custom'
    )),
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code TEXT NOT NULL UNIQUE,
    is_private BOOLEAN DEFAULT FALSE,
    max_members INTEGER DEFAULT 50,
    member_count INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `group_members` - Membres des groupes
```sql
CREATE TABLE group_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES social_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('creator', 'admin', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(group_id, user_id)
);
```

---

#### `social_posts` - Publications sociales
```sql
CREATE TABLE social_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID REFERENCES social_groups(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    post_type TEXT NOT NULL CHECK (post_type IN (
        'order_share', 'review', 'photo', 'text', 'event'
    )),
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    image_url TEXT,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `post_likes` - Likes sur les posts
```sql
CREATE TABLE post_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);
```

#### `post_comments` - Commentaires
```sql
CREATE TABLE post_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

### 8. Système de Notifications

#### `notifications` - Notifications
```sql
CREATE TABLE notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    from_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'info' CHECK (type IN (
        'info', 'warning', 'error', 'success', 
        'order_update', 'promotion', 'social'
    )),
    is_read BOOLEAN DEFAULT FALSE,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);
```

**Index :**
- `idx_notifications_user_id` : Notifications par utilisateur
- `idx_notifications_is_read` : Filtrage non lues
- `idx_notifications_type` : Filtrage par type

---

### 9. Système de Promotions

#### `promotions` - Codes promo
```sql
CREATE TABLE promotions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    promo_code TEXT NOT NULL UNIQUE,
    discount_type TEXT NOT NULL CHECK (discount_type IN (
        'percentage', 'fixed', 'free_delivery'
    )),
    discount_value DECIMAL(10,2) NOT NULL,
    min_order_amount DECIMAL(10,2) DEFAULT 0.0,
    max_discount DECIMAL(10,2),
    usage_limit INTEGER,
    used_count INTEGER DEFAULT 0,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `promotion_usage` - Utilisation des promotions
```sql
CREATE TABLE promotion_usage (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    discount_amount DECIMAL(10,2) NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

### 10. Système d'Analytics

#### `analytics_events` - Événements analytics
```sql
CREATE TABLE analytics_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    event_data JSONB DEFAULT '{}',
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

#### `user_preferences` - Préférences utilisateur (IA)
```sql
CREATE TABLE user_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    category_preferences JSONB DEFAULT '{}',
    price_range JSONB DEFAULT '{}',
    dietary_restrictions TEXT[] DEFAULT '{}',
    favorite_items TEXT[] DEFAULT '{}',
    disliked_items TEXT[] DEFAULT '{}',
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `recommendations` - Recommandations IA
```sql
CREATE TABLE recommendations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    recommendation_type TEXT NOT NULL CHECK (recommendation_type IN (
        'popular', 'similar', 'trending', 'personalized'
    )),
    score DECIMAL(5,4) NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

### 11. Système de Support

#### `support_tickets` - Tickets de support
```sql
CREATE TABLE support_tickets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    attachments TEXT[] DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN (
        'open', 'in_progress', 'resolved', 'closed'
    )),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution TEXT
);
```

#### `support_messages` - Messages de support
```sql
CREATE TABLE support_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
    admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

#### `complaints` - Réclamations
```sql
CREATE TABLE complaints (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('quality', 'delivery', 'service', 'other')),
    subject TEXT NOT NULL,
    description TEXT NOT NULL,
    photos TEXT[] DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'under_review', 'resolved', 'rejected'
    )),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolution TEXT
);
```

#### `return_requests` - Demandes de retour
```sql
CREATE TABLE return_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    items TEXT[] NOT NULL,
    refund_amount DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'approved', 'rejected', 'refunded'
    )),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE
);
```

---

### 12. Système de Formulaires

#### `saved_forms` - Formulaires sauvegardés
```sql
CREATE TABLE saved_forms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    form_name VARCHAR(100) NOT NULL,
    form_data JSONB NOT NULL,
    is_auto_save BOOLEAN DEFAULT false,
    last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### `validation_history` - Historique de validation
```sql
CREATE TABLE validation_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    form_name VARCHAR(100) NOT NULL,
    validation_result JSONB NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 🔗 Relations et Diagramme ERD

### Relations Principales

```
auth.users (Supabase Auth)
    ↓ (1:1)
users
    ├─ (1:N) → orders
    ├─ (1:N) → addresses
    ├─ (1:N) → notifications
    ├─ (1:N) → social_posts
    ├─ (1:N) → user_achievements
    ├─ (1:N) → user_challenges
    ├─ (1:N) → subscriptions
    ├─ (1:1) → drivers (si role='delivery')
    ├─ (1:1) → user_carts
    └─ (N:M) → social_groups (via group_members)

menu_categories
    └─ (1:N) → menu_items
        ├─ (1:N) → order_items
        ├─ (1:N) → product_reviews
        └─ (N:M) → customization_options (via menu_item_customizations)

orders
    ├─ (1:N) → order_items
    ├─ (1:N) → order_status_updates
    ├─ (1:1) → active_deliveries
    ├─ (1:N) → delivery_locations
    └─ (1:1) → group_payments

social_groups
    ├─ (1:N) → group_members
    ├─ (1:N) → social_posts
    └─ (1:N) → group_payments

achievements
    └─ (N:M) → users (via user_achievements)

challenges
    └─ (N:M) → users (via user_challenges)

promotions
    └─ (1:N) → promotion_usage
```

---

## 📋 Vues Importantes

### `available_drivers_view`
Liste des livreurs disponibles avec informations utilisateur

### `pending_verification_drivers_view`
Livreurs en attente de vérification

### `driver_stats_view`
Statistiques complètes des livreurs avec taux de complétion

### `delivery_stats`
Statistiques de livraison par livreur

### `active_orders_view`
Commandes en cours avec position en temps réel

### `menu_stats`
Statistiques de vente par article de menu

### `user_stats`
Statistiques d'utilisation par utilisateur

### `revenue_stats`
Revenus par période

### `category_management_view`
Gestion des catégories avec statistiques

### `popular_categories`
Catégories les plus populaires

---

## 🔒 Sécurité et RLS

### Politique Générale
- RLS activé sur toutes les tables sensibles
- Les utilisateurs ne voient que leurs propres données
- Les admins ont accès complet
- Les livreurs voient leurs livraisons assignées
- Données publiques : menu, catégories, promotions actives

### Triggers Automatiques

1. **`update_updated_at_column()`**
   - Mise à jour automatique du champ `updated_at`
   - Appliqué sur presque toutes les tables

2. **`notify_order_status_change()`**
   - Création automatique de notifications lors du changement de statut
   - Notification client + livreur

3. **`update_group_member_count()`**
   - Mise à jour du compteur de membres des groupes

4. **`update_post_counts()`**
   - Mise à jour des compteurs de likes et commentaires

5. **`update_menu_item_rating()`**
   - Calcul automatique de la note moyenne des articles

6. **`check_driver_role()`**
   - Vérification que seuls les users avec `role='delivery'` peuvent avoir un profil driver

---

## 📊 Index de Performance

### Index Critiques
- Toutes les clés étrangères sont indexées
- Index sur les champs de statut fréquemment filtrés
- Index composites pour les requêtes complexes
- Index géospatiaux pour la localisation

### Index Géospatiaux
- `idx_drivers_location` : Position des livreurs
- `idx_delivery_locations_order_id` + `timestamp` : Historique des positions

---

## 🎯 Points d'Attention

### Performance
1. **Nettoyage automatique** : La fonction `cleanup_old_delivery_locations()` devrait être appelée périodiquement
2. **Partitionnement** : Considérer le partitionnement pour `analytics_events` et `delivery_locations`
3. **Archivage** : Prévoir l'archivage des anciennes commandes

### Sécurité
1. **Clés API** : Stockées dans variables d'environnement (voir `SECURITY.md`)
2. **RLS** : Toutes les politiques sont en place
3. **Triggers** : Vérifications automatiques sur les données sensibles

### Données
1. **Seed Data** : Catégories et achievements par défaut inclus
2. **Migration** : Scripts de migration disponibles pour `drivers`
3. **Backup** : Configurer des sauvegardes automatiques régulières

---

## 📝 Notes de Migration

### De l'ancien schéma vers le nouveau

1. **Livreurs** : Migration automatique des champs de `users` vers `drivers`
2. **Abonnements** : Tables ajoutées, pas de migration nécessaire
3. **Reviews** : Nouvelle table, trigger de calcul automatique
4. **Admin Roles** : Nouvelles tables pour la gestion fine des permissions

---

## 🚀 Prochaines Évolutions

### Court Terme
- [ ] Table `marketing_campaigns` (mentionnée mais non créée)
- [ ] Table `driver_documents` pour la gestion des documents
- [ ] Table `driver_ratings` pour les notes détaillées

### Moyen Terme
- [ ] Système de cashback
- [ ] Programme de parrainage
- [ ] Gestion des favoris utilisateur

### Long Terme
- [ ] Intelligence artificielle pour les recommandations
- [ ] Analytics avancés en temps réel
- [ ] Système de réservation

---

## 📞 Contact et Support

Pour toute question sur ce schéma :
- Vérifier la documentation Supabase
- Consulter les fichiers SQL individuels dans `lib/database/`
- Référer aux modèles Dart dans `lib/models/`

---

**Version** : 1.0  
**Dernière mise à jour** : Décembre 2024  
**Base de données** : Supabase (PostgreSQL 15+)












