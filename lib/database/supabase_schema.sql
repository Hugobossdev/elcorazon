-- =====================================================
-- SCHEMA SUPABASE COMPLET - FastGo El Corazón
-- Système unifié pour 3 applications : Client, Livreur, Admin
-- =====================================================

-- =====================================================
-- 1. TABLES PRINCIPALES
-- =====================================================

-- Table des utilisateurs étendue
CREATE TABLE IF NOT EXISTS users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    auth_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(auth_user_id)
);

-- Table des adresses utilisateurs
CREATE TABLE IF NOT EXISTS addresses (
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

-- Table des catégories de menu
CREATE TABLE IF NOT EXISTS menu_categories (
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

-- Table des éléments de menu
CREATE TABLE IF NOT EXISTS menu_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    category_id UUID NOT NULL REFERENCES menu_categories(id) ON DELETE CASCADE,
    image_url TEXT,
    is_popular BOOLEAN DEFAULT FALSE,
    is_vegetarian BOOLEAN DEFAULT FALSE,
    is_vegan BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    available_quantity INTEGER DEFAULT 100,
    ingredients TEXT[] DEFAULT '{}',
    calories INTEGER DEFAULT 0,
    preparation_time INTEGER DEFAULT 15, -- en minutes
    rating DECIMAL(3,2) DEFAULT 0.0,
    review_count INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des options de personnalisation
CREATE TABLE IF NOT EXISTS customization_options (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('ingredient', 'sauce', 'size', 'cooking', 'extra', 'shape', 'flavor', 'filling', 'decoration', 'tiers', 'icing', 'dietary')),
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

-- Table de liaison menu items - options de personnalisation
CREATE TABLE IF NOT EXISTS menu_item_customizations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    customization_option_id UUID NOT NULL REFERENCES customization_options(id) ON DELETE CASCADE,
    is_required BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(menu_item_id, customization_option_id)
);

-- Table des commandes
CREATE TABLE IF NOT EXISTS orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delivery_person_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way', 'delivered', 'cancelled')),
    subtotal DECIMAL(10,2) NOT NULL,
    delivery_fee DECIMAL(10,2) DEFAULT 5.00,
    total DECIMAL(10,2) NOT NULL,
    delivery_address TEXT NOT NULL,
    delivery_latitude DECIMAL(10,8),
    delivery_longitude DECIMAL(11,8),
    delivery_notes TEXT,
    promo_code TEXT,
    discount DECIMAL(10,2) DEFAULT 0.00,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'card', 'wallet', 'mobile_money')),
    special_instructions TEXT,
    order_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    estimated_delivery_time TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    is_group_order BOOLEAN DEFAULT FALSE,
    group_id UUID, -- Pour les commandes groupées
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des éléments de commande
CREATE TABLE IF NOT EXISTS order_items (
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

-- Table des paiements groupés
CREATE TABLE IF NOT EXISTS group_payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID REFERENCES social_groups(id) ON DELETE SET NULL,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    initiated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(order_id)
);

-- Table des participants aux paiements groupés
CREATE TABLE IF NOT EXISTS group_payment_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_payment_id UUID NOT NULL REFERENCES group_payments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    operator TEXT,
    amount DECIMAL(10,2) NOT NULL,
    paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'paid', 'failed', 'cancelled')),
    transaction_id TEXT,
    payment_result JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des paniers utilisateurs
CREATE TABLE IF NOT EXISTS user_carts (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    delivery_fee DECIMAL(10,2) DEFAULT 500.0,
    discount DECIMAL(10,2) DEFAULT 0.0,
    promo_code TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des articles de panier
CREATE TABLE IF NOT EXISTS user_cart_items (
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

-- =====================================================
-- 2. SYSTÈME DE GAMIFICATION ET FIDÉLITÉ
-- =====================================================

-- Table des achievements
CREATE TABLE IF NOT EXISTS achievements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    icon TEXT NOT NULL,
    points_reward INTEGER DEFAULT 0,
    badge_reward TEXT,
    condition_type TEXT NOT NULL CHECK (condition_type IN ('orders_count', 'total_spent', 'streak_days', 'category_orders', 'special')),
    condition_value INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des achievements utilisateur
CREATE TABLE IF NOT EXISTS user_achievements (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0,
    is_unlocked BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, achievement_id)
);

-- Table des défis
CREATE TABLE IF NOT EXISTS challenges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    challenge_type TEXT NOT NULL CHECK (challenge_type IN ('daily', 'weekly', 'monthly', 'special')),
    target_value INTEGER NOT NULL,
    reward_points INTEGER DEFAULT 0,
    reward_discount DECIMAL(5,2) DEFAULT 0.0,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des participations aux défis
CREATE TABLE IF NOT EXISTS user_challenges (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, challenge_id)
);

-- Table des badges de fidélité
CREATE TABLE IF NOT EXISTS badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    icon TEXT NOT NULL DEFAULT '🏅',
    points_required INTEGER DEFAULT 0,
    criteria TEXT NOT NULL DEFAULT 'points',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table de progression des badges
CREATE TABLE IF NOT EXISTS user_badges (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0,
    is_unlocked BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, badge_id)
);

-- Table des récompenses de fidélité
CREATE TABLE IF NOT EXISTS loyalty_rewards (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    cost INTEGER NOT NULL,
    reward_type TEXT NOT NULL CHECK (reward_type IN ('discount', 'free_item', 'free_delivery', 'cashback', 'exclusive_offer')),
    value DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des transactions de fidélité
CREATE TABLE IF NOT EXISTS loyalty_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('earn', 'redeem', 'bonus', 'adjustment', 'expiration')),
    points INTEGER NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des récompenses échangées
CREATE TABLE IF NOT EXISTS reward_redemptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_id TEXT NOT NULL,
    cost INTEGER NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des abonnements (VIP et repas)
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subscription_type TEXT NOT NULL CHECK (subscription_type IN ('weekly', 'monthly', 'vip')),
    plan_name TEXT,
    meals_per_week INTEGER DEFAULT 0,
    price_per_meal DECIMAL(10,2) DEFAULT 0.0,
    monthly_price DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'cancelled', 'expired')),
    current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    meals_used_this_period INTEGER DEFAULT 0,
    auto_renew BOOLEAN DEFAULT TRUE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des commandes d'abonnement
CREATE TABLE IF NOT EXISTS subscription_orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    meal_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(subscription_id, order_id)
);

-- =====================================================
-- 3. SYSTÈME SOCIAL ET GROUPES
-- =====================================================

-- Table des groupes sociaux
CREATE TABLE IF NOT EXISTS social_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    group_type TEXT NOT NULL CHECK (group_type IN ('family', 'friends', 'work', 'neighborhood', 'custom')),
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code TEXT NOT NULL UNIQUE,
    is_private BOOLEAN DEFAULT FALSE,
    max_members INTEGER DEFAULT 50,
    member_count INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des membres de groupes
CREATE TABLE IF NOT EXISTS group_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES social_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('creator', 'admin', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(group_id, user_id)
);

-- Table des posts sociaux
CREATE TABLE IF NOT EXISTS social_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID REFERENCES social_groups(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    post_type TEXT NOT NULL CHECK (post_type IN ('order_share', 'review', 'photo', 'text', 'event')),
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    image_url TEXT,
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des likes
CREATE TABLE IF NOT EXISTS post_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- Table des commentaires
CREATE TABLE IF NOT EXISTS post_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 4. SYSTÈME DE PROMOTIONS ET CODES
-- =====================================================

-- Table des promotions
CREATE TABLE IF NOT EXISTS promotions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    promo_code TEXT NOT NULL UNIQUE,
    discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed', 'free_delivery')),
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

-- Table des utilisations de promotions
CREATE TABLE IF NOT EXISTS promotion_usage (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    discount_amount DECIMAL(10,2) NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 5. SYSTÈME DE GÉOLOCALISATION ET LIVRAISON
-- =====================================================

-- Table des positions des livreurs en temps réel
CREATE TABLE IF NOT EXISTS delivery_locations (
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

-- Table des livraisons actives
CREATE TABLE IF NOT EXISTS active_deliveries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    delivery_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'accepted', 'picked_up', 'on_the_way', 'delivered')),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,
    picked_up_at TIMESTAMP WITH TIME ZONE,
    started_delivery_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 6. SYSTÈME DE NOTIFICATIONS
-- =====================================================

-- Table des notifications
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    from_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'info' CHECK (type IN ('info', 'warning', 'error', 'success', 'order_update', 'promotion', 'social')),
    is_read BOOLEAN DEFAULT FALSE,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

-- =====================================================
-- 7. SYSTÈME DE SUIVI ET ANALYTICS
-- =====================================================

-- Table de suivi des commandes
CREATE TABLE IF NOT EXISTS order_tracking (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_tracking BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(order_id, user_id)
);

-- Table des mises à jour de statut des commandes
CREATE TABLE IF NOT EXISTS order_status_updates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des analytics
CREATE TABLE IF NOT EXISTS analytics_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    event_data JSONB DEFAULT '{}',
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 8. SYSTÈME DE RECOMMANDATIONS IA
-- =====================================================

-- Table des préférences utilisateur
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_preferences JSONB DEFAULT '{}',
    price_range JSONB DEFAULT '{}',
    dietary_restrictions TEXT[] DEFAULT '{}',
    favorite_items TEXT[] DEFAULT '{}',
    disliked_items TEXT[] DEFAULT '{}',
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Table des recommandations
CREATE TABLE IF NOT EXISTS recommendations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    recommendation_type TEXT NOT NULL CHECK (recommendation_type IN ('popular', 'similar', 'trending', 'personalized')),
    score DECIMAL(5,4) NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 9. SYSTÈME DE GESTION DES FORMULAIRES
-- =====================================================

-- Table des formulaires sauvegardés
CREATE TABLE IF NOT EXISTS saved_forms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    form_name VARCHAR(100) NOT NULL,
    form_data JSONB NOT NULL,
    is_auto_save BOOLEAN DEFAULT false,
    last_modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table de l'historique de validation
CREATE TABLE IF NOT EXISTS validation_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    form_name VARCHAR(100) NOT NULL,
    validation_result JSONB NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 10. INDEX POUR LES PERFORMANCES
-- =====================================================

-- Index pour les utilisateurs
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_online ON users(is_online);
CREATE INDEX IF NOT EXISTS idx_users_loyalty_points ON users(loyalty_points);
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);

-- Index pour le menu
CREATE INDEX IF NOT EXISTS idx_menu_items_category_id ON menu_items(category_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_is_available ON menu_items(is_available);
CREATE INDEX IF NOT EXISTS idx_menu_items_is_popular ON menu_items(is_popular);
CREATE INDEX IF NOT EXISTS idx_menu_items_price ON menu_items(price);

-- Index pour les commandes
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_person_id ON orders(delivery_person_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_is_group_order ON orders(is_group_order);
CREATE INDEX IF NOT EXISTS idx_orders_group_id ON orders(group_id);

-- Index pour les éléments de commande
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_menu_item_id ON order_items(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_user_cart_items_user_id ON user_cart_items(user_id);
CREATE INDEX IF NOT EXISTS idx_user_cart_items_menu_item_id ON user_cart_items(menu_item_id);
CREATE INDEX IF NOT EXISTS idx_group_payments_order_id ON group_payments(order_id);
CREATE INDEX IF NOT EXISTS idx_group_payments_status ON group_payments(status);
CREATE INDEX IF NOT EXISTS idx_group_payment_participants_payment_id ON group_payment_participants(group_payment_id);
CREATE INDEX IF NOT EXISTS idx_group_payment_participants_user_id ON group_payment_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_group_payment_participants_status ON group_payment_participants(status);

-- Index pour la fidélité
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_challenges_user_id ON user_challenges(user_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_transactions_user_id ON loyalty_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_reward_redemptions_user_id ON reward_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_type ON subscriptions(subscription_type);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscription_orders_subscription_id ON subscription_orders(subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscription_orders_order_id ON subscription_orders(order_id);

-- Index pour la géolocalisation
CREATE INDEX IF NOT EXISTS idx_delivery_locations_order_id ON delivery_locations(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_locations_delivery_id ON delivery_locations(delivery_id);
CREATE INDEX IF NOT EXISTS idx_delivery_locations_timestamp ON delivery_locations(timestamp);

-- Index pour les notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

-- Index pour les groupes sociaux
CREATE INDEX IF NOT EXISTS idx_social_groups_creator_id ON social_groups(creator_id);
CREATE INDEX IF NOT EXISTS idx_social_groups_invite_code ON social_groups(invite_code);
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);

-- Index pour les posts sociaux
CREATE INDEX IF NOT EXISTS idx_social_posts_user_id ON social_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_social_posts_group_id ON social_posts(group_id);
CREATE INDEX IF NOT EXISTS idx_social_posts_created_at ON social_posts(created_at);

-- Index pour les promotions
CREATE INDEX IF NOT EXISTS idx_promotions_promo_code ON promotions(promo_code);
CREATE INDEX IF NOT EXISTS idx_promotions_is_active ON promotions(is_active);
CREATE INDEX IF NOT EXISTS idx_promotions_start_date ON promotions(start_date);
CREATE INDEX IF NOT EXISTS idx_promotions_end_date ON promotions(end_date);

-- Index pour les analytics
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_type ON analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON analytics_events(created_at);

-- Index pour les formulaires sauvegardés
CREATE INDEX IF NOT EXISTS idx_saved_forms_user_id ON saved_forms(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_forms_form_name ON saved_forms(form_name);
CREATE INDEX IF NOT EXISTS idx_saved_forms_is_active ON saved_forms(is_active);
CREATE INDEX IF NOT EXISTS idx_saved_forms_last_modified ON saved_forms(last_modified);

-- Index pour l'historique de validation
CREATE INDEX IF NOT EXISTS idx_validation_history_user_id ON validation_history(user_id);
CREATE INDEX IF NOT EXISTS idx_validation_history_form_name ON validation_history(form_name);
CREATE INDEX IF NOT EXISTS idx_validation_history_timestamp ON validation_history(timestamp);

-- =====================================================
-- 11. TRIGGERS POUR MISE À JOUR AUTOMATIQUE
-- =====================================================

-- Fonction pour mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers pour updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_categories_updated_at BEFORE UPDATE ON menu_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_items_updated_at BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_customization_options_updated_at BEFORE UPDATE ON customization_options
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_payments_updated_at BEFORE UPDATE ON group_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_payment_participants_updated_at BEFORE UPDATE ON group_payment_participants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_delivery_locations_updated_at BEFORE UPDATE ON delivery_locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_active_deliveries_updated_at BEFORE UPDATE ON active_deliveries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_social_groups_updated_at BEFORE UPDATE ON social_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_social_posts_updated_at BEFORE UPDATE ON social_posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_promotions_updated_at BEFORE UPDATE ON promotions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_order_tracking_updated_at BEFORE UPDATE ON order_tracking
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_saved_forms_updated_at BEFORE UPDATE ON saved_forms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 12. FONCTIONS MÉTIER
-- =====================================================

-- Fonction pour créer une notification automatique lors du changement de statut
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Insérer une notification pour le client
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (
        NEW.user_id,
        'Mise à jour de commande',
        'Votre commande #' || SUBSTRING(NEW.id::text, 1, 8) || ' est maintenant ' || NEW.status,
        'order_update',
        jsonb_build_object('order_id', NEW.id, 'status', NEW.status)
    );
    
    -- Si une livraison est assignée, notifier le livreur
    IF NEW.delivery_person_id IS NOT NULL THEN
        INSERT INTO notifications (user_id, title, message, type, data)
        VALUES (
            NEW.delivery_person_id,
            'Nouvelle livraison',
            'Nouvelle livraison assignée: Commande #' || SUBSTRING(NEW.id::text, 1, 8),
            'order_update',
            jsonb_build_object('order_id', NEW.id, 'status', NEW.status)
        );
    END IF;
    
    -- Insérer une mise à jour de statut
    INSERT INTO order_status_updates (order_id, status, updated_by, notes)
    VALUES (NEW.id, NEW.status, NEW.delivery_person_id, 'Statut mis à jour automatiquement');
    
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_notify_order_status_change AFTER UPDATE ON orders
    FOR EACH ROW 
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION notify_order_status_change();

-- Fonction pour mettre à jour le compteur de membres d'un groupe
CREATE OR REPLACE FUNCTION update_group_member_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE social_groups 
        SET member_count = member_count + 1 
        WHERE id = NEW.group_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE social_groups 
        SET member_count = member_count - 1 
        WHERE id = OLD.group_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_update_group_member_count 
    AFTER INSERT OR DELETE ON group_members
    FOR EACH ROW EXECUTE FUNCTION update_group_member_count();

-- Fonction pour mettre à jour les compteurs de likes et commentaires
CREATE OR REPLACE FUNCTION update_post_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND TG_TABLE_NAME = 'post_likes' THEN
        UPDATE social_posts 
        SET likes_count = likes_count + 1 
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' AND TG_TABLE_NAME = 'post_likes' THEN
        UPDATE social_posts 
        SET likes_count = likes_count - 1 
        WHERE id = OLD.post_id;
        RETURN OLD;
    ELSIF TG_OP = 'INSERT' AND TG_TABLE_NAME = 'post_comments' THEN
        UPDATE social_posts 
        SET comments_count = comments_count + 1 
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' AND TG_TABLE_NAME = 'post_comments' THEN
        UPDATE social_posts 
        SET comments_count = comments_count - 1 
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

CREATE TRIGGER trigger_update_post_likes_count 
    AFTER INSERT OR DELETE ON post_likes
    FOR EACH ROW EXECUTE FUNCTION update_post_counts();

CREATE TRIGGER trigger_update_post_comments_count 
    AFTER INSERT OR DELETE ON post_comments
    FOR EACH ROW EXECUTE FUNCTION update_post_counts();

-- Fonction pour nettoyer les anciennes positions de livreurs
CREATE OR REPLACE FUNCTION cleanup_old_delivery_locations()
RETURNS void AS $$
BEGIN
    DELETE FROM delivery_locations 
    WHERE created_at < NOW() - INTERVAL '24 hours';
END;
$$ language 'plpgsql';

-- =====================================================
-- 12. FONCTIONS MÉTIER POUR LA GESTION DES CATÉGORIES
-- =====================================================

-- Fonction pour créer une catégorie avec validation
CREATE OR REPLACE FUNCTION create_menu_category(
    p_name TEXT,
    p_display_name TEXT,
    p_emoji TEXT,
    p_description TEXT DEFAULT NULL,
    p_sort_order INTEGER DEFAULT 0
)
RETURNS UUID AS $$
DECLARE
    category_id UUID;
BEGIN
    -- Vérifier que l'utilisateur est admin
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE auth_user_id = auth.uid() 
        AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Seuls les administrateurs peuvent créer des catégories';
    END IF;
    
    -- Vérifier que le nom n'existe pas déjà
    IF EXISTS (SELECT 1 FROM menu_categories WHERE name = p_name) THEN
        RAISE EXCEPTION 'Une catégorie avec ce nom existe déjà';
    END IF;
    
    -- Insérer la nouvelle catégorie
    INSERT INTO menu_categories (name, display_name, emoji, description, sort_order)
    VALUES (p_name, p_display_name, p_emoji, p_description, p_sort_order)
    RETURNING id INTO category_id;
    
    RETURN category_id;
END;
$$ language 'plpgsql';

-- Fonction pour mettre à jour une catégorie
CREATE OR REPLACE FUNCTION update_menu_category(
    p_id UUID,
    p_name TEXT DEFAULT NULL,
    p_display_name TEXT DEFAULT NULL,
    p_emoji TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_sort_order INTEGER DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Vérifier que l'utilisateur est admin
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE auth_user_id = auth.uid() 
        AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Seuls les administrateurs peuvent modifier des catégories';
    END IF;
    
    -- Vérifier que la catégorie existe
    IF NOT EXISTS (SELECT 1 FROM menu_categories WHERE id = p_id) THEN
        RAISE EXCEPTION 'Catégorie non trouvée';
    END IF;
    
    -- Vérifier l'unicité du nom si fourni
    IF p_name IS NOT NULL AND EXISTS (
        SELECT 1 FROM menu_categories 
        WHERE name = p_name AND id != p_id
    ) THEN
        RAISE EXCEPTION 'Une catégorie avec ce nom existe déjà';
    END IF;
    
    -- Mettre à jour la catégorie
    UPDATE menu_categories SET
        name = COALESCE(p_name, name),
        display_name = COALESCE(p_display_name, display_name),
        emoji = COALESCE(p_emoji, emoji),
        description = COALESCE(p_description, description),
        sort_order = COALESCE(p_sort_order, sort_order),
        is_active = COALESCE(p_is_active, is_active),
        updated_at = NOW()
    WHERE id = p_id;
    
    RETURN TRUE;
END;
$$ language 'plpgsql';

-- Fonction pour supprimer une catégorie (soft delete)
CREATE OR REPLACE FUNCTION delete_menu_category(p_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    item_count INTEGER;
BEGIN
    -- Vérifier que l'utilisateur est admin
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE auth_user_id = auth.uid() 
        AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Seuls les administrateurs peuvent supprimer des catégories';
    END IF;
    
    -- Vérifier que la catégorie existe
    IF NOT EXISTS (SELECT 1 FROM menu_categories WHERE id = p_id) THEN
        RAISE EXCEPTION 'Catégorie non trouvée';
    END IF;
    
    -- Compter les éléments de menu dans cette catégorie
    SELECT COUNT(*) INTO item_count 
    FROM menu_items 
    WHERE category_id = p_id AND is_available = true;
    
    -- Si la catégorie contient des éléments actifs, refuser la suppression
    IF item_count > 0 THEN
        RAISE EXCEPTION 'Impossible de supprimer une catégorie contenant des éléments de menu actifs (% éléments)', item_count;
    END IF;
    
    -- Désactiver la catégorie (soft delete)
    UPDATE menu_categories 
    SET is_active = false, updated_at = NOW()
    WHERE id = p_id;
    
    RETURN TRUE;
END;
$$ language 'plpgsql';

-- Fonction pour réorganiser l'ordre des catégories
CREATE OR REPLACE FUNCTION reorder_menu_categories(
    p_category_orders JSONB
)
RETURNS BOOLEAN AS $$
DECLARE
    category_order JSONB;
BEGIN
    -- Vérifier que l'utilisateur est admin
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE auth_user_id = auth.uid() 
        AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Seuls les administrateurs peuvent réorganiser les catégories';
    END IF;
    
    -- Mettre à jour l'ordre de chaque catégorie
    FOR category_order IN SELECT * FROM jsonb_array_elements(p_category_orders)
    LOOP
        UPDATE menu_categories 
        SET sort_order = (category_order->>'sort_order')::INTEGER,
            updated_at = NOW()
        WHERE id = (category_order->>'id')::UUID;
    END LOOP;
    
    RETURN TRUE;
END;
$$ language 'plpgsql';

-- Fonction pour obtenir les statistiques d'une catégorie
CREATE OR REPLACE FUNCTION get_category_stats(p_category_id UUID)
RETURNS JSONB AS $$
DECLARE
    stats JSONB;
    total_items INTEGER;
    active_items INTEGER;
    total_revenue DECIMAL(10,2);
    avg_rating DECIMAL(3,2);
BEGIN
    -- Compter les éléments totaux
    SELECT COUNT(*) INTO total_items
    FROM menu_items 
    WHERE category_id = p_category_id;
    
    -- Compter les éléments actifs
    SELECT COUNT(*) INTO active_items
    FROM menu_items 
    WHERE category_id = p_category_id AND is_available = true;
    
    -- Calculer le revenu total
    SELECT COALESCE(SUM(oi.total_price), 0) INTO total_revenue
    FROM menu_items mi
    JOIN order_items oi ON mi.id = oi.menu_item_id
    JOIN orders o ON oi.order_id = o.id
    WHERE mi.category_id = p_category_id 
    AND o.status = 'delivered';
    
    -- Calculer la note moyenne
    SELECT COALESCE(AVG(mi.rating), 0) INTO avg_rating
    FROM menu_items mi
    WHERE mi.category_id = p_category_id 
    AND mi.rating > 0;
    
    -- Construire l'objet de statistiques
    stats := jsonb_build_object(
        'total_items', total_items,
        'active_items', active_items,
        'inactive_items', total_items - active_items,
        'total_revenue', total_revenue,
        'average_rating', avg_rating,
        'popularity_score', CASE 
            WHEN total_items > 0 THEN (active_items::DECIMAL / total_items) * 100
            ELSE 0
        END
    );
    
    RETURN stats;
END;
$$ language 'plpgsql';

-- =====================================================
-- 13. POLITIQUES RLS (ROW LEVEL SECURITY)
-- =====================================================

-- Activer RLS sur toutes les tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE customization_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_item_customizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_payment_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE social_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE social_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE validation_history ENABLE ROW LEVEL SECURITY;

-- Politiques pour les utilisateurs
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename = 'users' 
          AND policyname = 'Users can view their own profile'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their own profile" ON users
            FOR SELECT USING (
                auth.uid()::text = auth_user_id::text
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename = 'users' 
          AND policyname = 'Users can update their own profile'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can update their own profile" ON users
            FOR UPDATE USING (
                auth.uid()::text = auth_user_id::text
                OR auth.role() = 'service_role'
            ) WITH CHECK (
                auth.uid()::text = auth_user_id::text
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename = 'users' 
          AND policyname = 'Users can insert their own profile'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can insert their own profile" ON users
            FOR INSERT WITH CHECK (
                auth.uid()::text = auth_user_id::text
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;
END $$;

-- Politiques pour les adresses
CREATE POLICY "Users can view their own addresses" ON addresses
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can manage their own addresses" ON addresses
    FOR ALL USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politiques pour le menu (lecture publique)
CREATE POLICY "Menu categories are publicly readable" ON menu_categories
    FOR SELECT USING (true);

CREATE POLICY "Menu items are publicly readable" ON menu_items
    FOR SELECT USING (true);

CREATE POLICY "Customization options are publicly readable" ON customization_options
    FOR SELECT USING (true);

CREATE POLICY "Menu item customizations are publicly readable" ON menu_item_customizations
    FOR SELECT USING (true);

-- Politiques pour les commandes
CREATE POLICY "Users can view their own orders" ON orders
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        ) OR 
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = delivery_person_id
        )
    );

CREATE POLICY "Users can create their own orders" ON orders
    FOR INSERT WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Delivery persons can update assigned orders" ON orders
    FOR UPDATE USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = delivery_person_id
        )
    );

-- Politiques pour les éléments de commande
CREATE POLICY "Users can view items of their orders" ON order_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = order_items.order_id 
            AND (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = orders.user_id
                ) OR 
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = orders.delivery_person_id
                )
            )
        )
    );

CREATE POLICY "Users can insert items to their orders" ON order_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = order_items.order_id 
            AND auth.uid()::text = (
                SELECT auth_user_id::text FROM users WHERE id = orders.user_id
            )
        )
    );

-- Politiques pour les paniers
CREATE POLICY "Users can view their cart" ON user_carts
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can manage their cart" ON user_carts
    FOR ALL USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can view their cart items" ON user_cart_items
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can manage their cart items" ON user_cart_items
    FOR ALL USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politiques pour les paiements groupés
CREATE POLICY "Users can view their group payments" ON group_payments
    FOR SELECT USING (
        auth.role() = 'service_role'
        OR auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = initiated_by
        )
        OR EXISTS (
            SELECT 1 FROM group_payment_participants gpp
            JOIN users u ON u.id = gpp.user_id
            WHERE gpp.group_payment_id = group_payments.id
              AND u.auth_user_id::text = auth.uid()::text
        )
    );

CREATE POLICY "Users can create their group payments" ON group_payments
    FOR INSERT WITH CHECK (
        auth.role() = 'service_role'
        OR EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = initiated_by
              AND u.auth_user_id::text = auth.uid()::text
        )
    );

CREATE POLICY "Users can update their group payments" ON group_payments
    FOR UPDATE USING (
        auth.role() = 'service_role'
        OR auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = initiated_by
        )
        OR EXISTS (
            SELECT 1 FROM group_payment_participants gpp
            JOIN users u ON u.id = gpp.user_id
            WHERE gpp.group_payment_id = group_payments.id
              AND u.auth_user_id::text = auth.uid()::text
        )
    ) WITH CHECK (
        auth.role() = 'service_role'
        OR auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = initiated_by
        )
        OR EXISTS (
            SELECT 1 FROM group_payment_participants gpp
            JOIN users u ON u.id = gpp.user_id
            WHERE gpp.group_payment_id = group_payments.id
              AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politiques pour les participants aux paiements groupés
CREATE POLICY "Users can view group payment participants" ON group_payment_participants
    FOR SELECT USING (
        auth.role() = 'service_role'
        OR (
            user_id IS NOT NULL AND auth.uid()::text = (
                SELECT auth_user_id::text FROM users WHERE id = user_id
            )
        )
        OR EXISTS (
            SELECT 1 FROM group_payments gp
            JOIN users u ON u.id = gp.initiated_by
            WHERE gp.id = group_payment_participants.group_payment_id
              AND u.auth_user_id::text = auth.uid()::text
        )
    );

CREATE POLICY "Users can manage group payment participants" ON group_payment_participants
    FOR ALL USING (
        auth.role() = 'service_role'
        OR (
            user_id IS NOT NULL AND auth.uid()::text = (
                SELECT auth_user_id::text FROM users WHERE id = user_id
            )
        )
        OR EXISTS (
            SELECT 1 FROM group_payments gp
            JOIN users u ON u.id = gp.initiated_by
            WHERE gp.id = group_payment_participants.group_payment_id
              AND u.auth_user_id::text = auth.uid()::text
        )
    ) WITH CHECK (
        auth.role() = 'service_role'
        OR (
            user_id IS NOT NULL AND auth.uid()::text = (
                SELECT auth_user_id::text FROM users WHERE id = user_id
            )
        )
        OR EXISTS (
            SELECT 1 FROM group_payments gp
            JOIN users u ON u.id = gp.initiated_by
            WHERE gp.id = group_payment_participants.group_payment_id
              AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politiques pour les positions de livraison
CREATE POLICY "Users can view delivery locations of their orders" ON delivery_locations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = delivery_locations.order_id 
            AND (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = orders.user_id
                ) OR 
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = orders.delivery_person_id
                )
            )
        )
    );

CREATE POLICY "Delivery persons can update their locations" ON delivery_locations
    FOR INSERT WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = delivery_id
        )
    );

-- Politiques pour les notifications
CREATE POLICY "Users can view their own notifications" ON notifications
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can mark their notifications as read" ON notifications
    FOR UPDATE USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politiques pour les groupes sociaux
CREATE POLICY "Users can view public groups and their own groups" ON social_groups
    FOR SELECT USING (
        is_private = false OR 
        EXISTS (
            SELECT 1 FROM group_members 
            WHERE group_id = social_groups.id 
            AND auth.uid()::text = (
                SELECT auth_user_id::text FROM users WHERE id = user_id
            )
        )
    );

CREATE POLICY "Users can create groups" ON social_groups
    FOR INSERT WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = creator_id
        )
    );

-- Politiques pour les membres de groupes
CREATE POLICY "Users can view group members" ON group_members
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
        OR EXISTS (
            SELECT 1 FROM social_groups sg
            WHERE sg.id = group_id
              AND (
                  sg.is_private = false OR
                  sg.creator_id = (
                      SELECT id FROM users WHERE auth_user_id = auth.uid()
                  )
              )
        )
    );

CREATE POLICY "Users can manage their membership" ON group_members
    FOR ALL USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politiques pour les posts sociaux
CREATE POLICY "Users can view public posts and posts from their groups" ON social_posts
    FOR SELECT USING (
        is_public = true OR 
        EXISTS (
            SELECT 1 FROM group_members 
            WHERE group_id = social_posts.group_id 
            AND auth.uid()::text = (
                SELECT auth_user_id::text FROM users WHERE id = user_id
            )
        )
    );

CREATE POLICY "Users can create posts" ON social_posts
    FOR INSERT WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politiques pour la fidélité
CREATE POLICY "Loyalty rewards are publicly readable" ON loyalty_rewards
    FOR SELECT USING (is_active = true);

CREATE POLICY "Admins can manage loyalty rewards" ON loyalty_rewards
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

CREATE POLICY "Users can view their loyalty transactions" ON loyalty_transactions
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Admins can manage loyalty transactions" ON loyalty_transactions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

CREATE POLICY "Users can view their reward redemptions" ON reward_redemptions
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can manage their reward redemptions" ON reward_redemptions
    FOR ALL USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politiques pour les abonnements
CREATE POLICY "Users can view their own subscriptions" ON subscriptions
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can create their own subscriptions" ON subscriptions
    FOR INSERT WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can update their own subscriptions" ON subscriptions
    FOR UPDATE USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can view their subscription orders" ON subscription_orders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM subscriptions s
            JOIN users u ON u.id = s.user_id
            WHERE s.id = subscription_orders.subscription_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

CREATE POLICY "Users can create subscription orders" ON subscription_orders
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM subscriptions s
            JOIN users u ON u.id = s.user_id
            WHERE s.id = subscription_orders.subscription_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

CREATE POLICY "Users can view their achievements" ON user_achievements
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can update their achievements" ON user_achievements
    FOR ALL USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can view their challenges" ON user_challenges
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can update their challenges" ON user_challenges
    FOR ALL USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Badges are publicly readable" ON badges
    FOR SELECT USING (is_active = true);

CREATE POLICY "Users can view their badges" ON user_badges
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

CREATE POLICY "Users can update their badges" ON user_badges
    FOR ALL USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politiques pour les promotions (lecture publique)
CREATE POLICY "Promotions are publicly readable" ON promotions
    FOR SELECT USING (is_active = true);

-- Politiques pour les analytics (admins seulement)
CREATE POLICY "Admins can view analytics" ON analytics_events
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Politiques pour les formulaires sauvegardés
CREATE POLICY "Users can view their own saved forms" ON saved_forms
    FOR SELECT USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can create their own saved forms" ON saved_forms
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Users can update their own saved forms" ON saved_forms
    FOR UPDATE USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can delete their own saved forms" ON saved_forms
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- Politiques pour l'historique de validation
CREATE POLICY "Users can view their own validation history" ON validation_history
    FOR SELECT USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can create their own validation history" ON validation_history
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

-- =====================================================
-- 14. VUES POUR LES STATISTIQUES ET ANALYTICS
-- =====================================================

-- Vue pour les statistiques de livraison
CREATE VIEW delivery_stats AS
SELECT 
    delivery_id,
    COUNT(*) as total_deliveries,
    COUNT(CASE WHEN status = 'delivered' THEN 1 END) as completed_deliveries,
    AVG(EXTRACT(EPOCH FROM (delivered_at - assigned_at))/60) as avg_delivery_time_minutes,
    COUNT(CASE WHEN status = 'delivered' AND delivered_at - assigned_at < INTERVAL '30 minutes' THEN 1 END) as on_time_deliveries
FROM active_deliveries 
WHERE status = 'delivered'
GROUP BY delivery_id;

-- Vue pour les commandes en cours
CREATE VIEW active_orders_view AS
SELECT 
    o.*,
    ad.status as delivery_status,
    ad.assigned_at,
    dl.latitude as current_latitude,
    dl.longitude as current_longitude,
    dl.timestamp as last_location_update
FROM orders o
LEFT JOIN active_deliveries ad ON o.id = ad.order_id
LEFT JOIN LATERAL (
    SELECT latitude, longitude, timestamp
    FROM delivery_locations dl2
    WHERE dl2.order_id = o.id
    ORDER BY dl2.timestamp DESC
    LIMIT 1
) dl ON true
WHERE o.status NOT IN ('delivered', 'cancelled');

-- Vue pour les statistiques de menu
CREATE VIEW menu_stats AS
SELECT 
    mi.id,
    mi.name,
    mi.category_id,
    mc.name as category_name,
    COUNT(oi.id) as order_count,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.total_price) as total_revenue,
    AVG(oi.quantity) as avg_quantity_per_order
FROM menu_items mi
LEFT JOIN menu_categories mc ON mi.category_id = mc.id
LEFT JOIN order_items oi ON mi.id = oi.menu_item_id
LEFT JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'delivered'
GROUP BY mi.id, mi.name, mi.category_id, mc.name;

-- Vue pour les statistiques utilisateur
CREATE VIEW user_stats AS
SELECT 
    u.id,
    u.name,
    u.role,
    u.loyalty_points,
    COUNT(DISTINCT o.id) as total_orders,
    SUM(o.total) as total_spent,
    AVG(o.total) as avg_order_value,
    MAX(o.created_at) as last_order_date
FROM users u
LEFT JOIN orders o ON u.id = o.user_id AND o.status = 'delivered'
GROUP BY u.id, u.name, u.role, u.loyalty_points;

-- Vue pour les revenus par période
CREATE VIEW revenue_stats AS
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as order_count,
    SUM(total) as daily_revenue,
    AVG(total) as avg_order_value
FROM orders 
WHERE status = 'delivered'
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;

-- Vue pour la gestion des catégories avec statistiques
CREATE VIEW category_management_view AS
SELECT 
    mc.id,
    mc.name,
    mc.display_name,
    mc.emoji,
    mc.description,
    mc.sort_order,
    mc.is_active,
    mc.created_at,
    mc.updated_at,
    COUNT(mi.id) as total_items,
    COUNT(CASE WHEN mi.is_available = true THEN 1 END) as active_items,
    COUNT(CASE WHEN mi.is_available = false THEN 1 END) as inactive_items,
    COALESCE(SUM(CASE WHEN o.status = 'delivered' THEN oi.total_price ELSE 0 END), 0) as total_revenue,
    COALESCE(AVG(CASE WHEN mi.rating > 0 THEN mi.rating END), 0) as average_rating,
    CASE 
        WHEN COUNT(mi.id) > 0 THEN 
            (COUNT(CASE WHEN mi.is_available = true THEN 1 END)::DECIMAL / COUNT(mi.id)) * 100
        ELSE 0
    END as popularity_score
FROM menu_categories mc
LEFT JOIN menu_items mi ON mc.id = mi.category_id
LEFT JOIN order_items oi ON mi.id = oi.menu_item_id
LEFT JOIN orders o ON oi.order_id = o.id
GROUP BY mc.id, mc.name, mc.display_name, mc.emoji, mc.description, 
         mc.sort_order, mc.is_active, mc.created_at, mc.updated_at
ORDER BY mc.sort_order, mc.name;

-- Vue pour les catégories populaires
CREATE VIEW popular_categories AS
SELECT 
    mc.id,
    mc.name,
    mc.display_name,
    mc.emoji,
    COUNT(oi.id) as order_count,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.total_price) as total_revenue,
    AVG(oi.quantity) as avg_quantity_per_order
FROM menu_categories mc
JOIN menu_items mi ON mc.id = mi.category_id
JOIN order_items oi ON mi.id = oi.menu_item_id
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'delivered'
  AND mc.is_active = true
  AND mi.is_available = true
GROUP BY mc.id, mc.name, mc.display_name, mc.emoji
ORDER BY total_revenue DESC;

-- =====================================================
-- 15. DONNÉES DE BASE (SEED DATA)
-- =====================================================

-- Insérer les catégories de menu
INSERT INTO menu_categories (name, display_name, emoji, description, sort_order) VALUES
('burgers', 'Burgers', '🍔', 'Nos délicieux burgers artisanaux', 1),
('pizzas', 'Pizzas', '🍕', 'Pizzas fraîches cuites au feu de bois', 2),
('drinks', 'Boissons', '🥤', 'Boissons fraîches et chaudes', 3),
('desserts', 'Desserts', '🍰', 'Desserts gourmands et sucrés', 4),
('sides', 'Accompagnements', '🍟', 'Accompagnements croustillants', 5),
('salads', 'Salades', '🥗', 'Salades fraîches et équilibrées', 6),
('combos', 'Menus', '🍽️', 'Menus complets à prix avantageux', 7),
('specials', 'Spécialités', '⭐', 'Nos spécialités du chef', 8)
ON CONFLICT (name) DO NOTHING;

-- Insérer les options de personnalisation
INSERT INTO customization_options (name, category, price_modifier, is_default, max_quantity, description) VALUES
-- Ingrédients
('Salade', 'ingredient', 0.0, true, 1, 'Salade fraîche'),
('Tomate', 'ingredient', 0.0, true, 1, 'Tomate fraîche'),
('Oignon', 'ingredient', 0.0, false, 1, 'Oignon cru'),
('Cornichon', 'ingredient', 0.0, false, 1, 'Cornichon aigre-doux'),
('Fromage', 'ingredient', 1.0, false, 1, 'Fromage cheddar'),
('Bacon', 'ingredient', 2.0, false, 1, 'Bacon croustillant'),
('Champignon', 'ingredient', 1.5, false, 1, 'Champignon grillé'),

-- Sauces
('Ketchup', 'sauce', 0.0, true, 1, 'Ketchup classique'),
('Mayonnaise', 'sauce', 0.0, false, 1, 'Mayonnaise crémeuse'),
('Moutarde', 'sauce', 0.0, false, 1, 'Moutarde de Dijon'),
('Sauce BBQ', 'sauce', 0.5, false, 1, 'Sauce barbecue fumée'),
('Sauce Piquante', 'sauce', 0.5, false, 1, 'Sauce épicée'),

-- Tailles
('Petit', 'size', 0.0, true, 1, 'Portion petite'),
('Moyen', 'size', 2.0, false, 1, 'Portion moyenne'),
('Grand', 'size', 4.0, false, 1, 'Portion grande'),

-- Cuisson
('Saignant', 'cooking', 0.0, false, 1, 'Cuisson saignante'),
('À point', 'cooking', 0.0, true, 1, 'Cuisson à point'),
('Bien cuit', 'cooking', 0.0, false, 1, 'Cuisson bien cuite'),

-- Extras
('Frites', 'extra', 3.0, false, 1, 'Portion de frites'),
('Boisson', 'extra', 2.5, false, 1, 'Boisson au choix'),
('Dessert', 'extra', 4.0, false, 1, 'Dessert au choix')
ON CONFLICT DO NOTHING;

-- Insérer des achievements de base
INSERT INTO achievements (name, description, icon, points_reward, badge_reward, condition_type, condition_value) VALUES
('Premier Pas', 'Effectuez votre première commande', '🎯', 50, 'first_order', 'orders_count', 1),
('Gourmand', 'Commandez 10 fois', '🍔', 200, 'food_lover', 'orders_count', 10),
('Fidèle', 'Commandez 50 fois', '👑', 1000, 'loyal_customer', 'orders_count', 50),
('Gros Budget', 'Dépensez 100€ au total', '💰', 300, 'big_spender', 'total_spent', 100),
('Streak Master', 'Commandez 7 jours consécutifs', '🔥', 500, 'streak_master', 'streak_days', 7),
('Végétarien', 'Commandez 5 plats végétariens', '🥗', 150, 'vegetarian', 'category_orders', 5),
('Pizza Lover', 'Commandez 10 pizzas', '🍕', 250, 'pizza_lover', 'category_orders', 10)
ON CONFLICT (name) DO NOTHING;

-- =====================================================
-- 16. COMMENTAIRES FINAUX
-- =====================================================

-- Ce schéma est conçu pour supporter :
-- ✅ 3 applications (Client, Livreur, Admin)
-- ✅ Système de commandes complet avec personnalisation
-- ✅ Gamification et fidélité
-- ✅ Fonctionnalités sociales et groupes
-- ✅ Suivi en temps réel et géolocalisation
-- ✅ Système de promotions et codes
-- ✅ Analytics et statistiques
-- ✅ Recommandations IA
-- ✅ Notifications en temps réel
-- ✅ Sécurité avec RLS
-- ✅ Performance avec index optimisés
-- ✅ Triggers automatiques
-- =====================================================
-- 10. SYSTÈME DE GESTION DES LIVREURS
-- =====================================================

-- Table des livreurs
CREATE TABLE IF NOT EXISTS drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    status VARCHAR(20) DEFAULT 'offline' CHECK (status IN ('available', 'busy', 'on_delivery', 'offline')),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    vehicle_type VARCHAR(50),
    license_plate VARCHAR(20),
    rating DECIMAL(3, 2) DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
    total_deliveries INTEGER DEFAULT 0,
    total_earnings DECIMAL(10, 2) DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_online TIMESTAMP WITH TIME ZONE,
    profile_image_url TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT true
);

-- Index pour les livreurs
CREATE INDEX IF NOT EXISTS idx_drivers_auth_user_id ON drivers(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_drivers_status ON drivers(status);
CREATE INDEX IF NOT EXISTS idx_drivers_is_active ON drivers(is_active);
CREATE INDEX IF NOT EXISTS idx_drivers_rating ON drivers(rating);
CREATE INDEX IF NOT EXISTS idx_drivers_location ON drivers(latitude, longitude);

-- RLS pour les livreurs
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

-- Politiques pour les livreurs
CREATE POLICY "Users can view all drivers" ON drivers
    FOR SELECT USING (true);

CREATE POLICY "Admins can manage drivers" ON drivers
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

CREATE POLICY "Drivers can manage their own profile" ON drivers
    FOR ALL USING (auth_user_id = auth.uid());

-- Trigger pour drivers
CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ✅ Vues pour les statistiques

-- Pour utiliser ce schéma :
-- 1. Exécuter dans l'éditeur SQL de Supabase
-- 2. Configurer les variables d'environnement dans les apps
-- 3. Tester les politiques RLS
-- 4. Vérifier les triggers et fonctions
-- 5. Insérer des données de test si nécessaire