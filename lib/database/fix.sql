-- =====================================================
-- Script de correction des politiques RLS existantes
-- Vérifie l'existence avant création
-- =====================================================

DO $$
BEGIN
    -- users
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'users' 
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
        WHERE schemaname = 'public' AND tablename = 'users' 
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
        WHERE schemaname = 'public' AND tablename = 'users' 
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

    -- addresses
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'addresses' 
          AND policyname = 'Users can view their own addresses'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their own addresses" ON addresses
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'addresses' 
          AND policyname = 'Users can manage their own addresses'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can manage their own addresses" ON addresses
            FOR ALL USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            ) WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- menu_categories
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'menu_categories' 
          AND policyname = 'Menu categories are publicly readable'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Menu categories are publicly readable" ON menu_categories
            FOR SELECT USING (true);
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'menu_categories' 
          AND policyname = 'Admins can create menu categories'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Admins can create menu categories" ON menu_categories
            FOR INSERT WITH CHECK (
                EXISTS (
                    SELECT 1 FROM users 
                    WHERE auth_user_id = auth.uid() 
                    AND role = 'admin'
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'menu_categories' 
          AND policyname = 'Admins can update menu categories'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Admins can update menu categories" ON menu_categories
            FOR UPDATE USING (
                EXISTS (
                    SELECT 1 FROM users 
                    WHERE auth_user_id = auth.uid() 
                    AND role = 'admin'
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'menu_categories' 
          AND policyname = 'Admins can delete menu categories'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Admins can delete menu categories" ON menu_categories
            FOR DELETE USING (
                EXISTS (
                    SELECT 1 FROM users 
                    WHERE auth_user_id = auth.uid() 
                    AND role = 'admin'
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- menu_items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'menu_items' 
          AND policyname = 'Menu items are publicly readable'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Menu items are publicly readable" ON menu_items
            FOR SELECT USING (true);
        $policy$;
    END IF;

    -- customization_options
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'customization_options' 
          AND policyname = 'Customization options are publicly readable'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Customization options are publicly readable" ON customization_options
            FOR SELECT USING (true);
        $policy$;
    END IF;

    -- menu_item_customizations
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'menu_item_customizations' 
          AND policyname = 'Menu item customizations are publicly readable'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Menu item customizations are publicly readable" ON menu_item_customizations
            FOR SELECT USING (true);
        $policy$;
    END IF;

    -- orders
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'orders' 
          AND policyname = 'Users can view their own orders'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their own orders" ON orders
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = delivery_person_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'orders' 
          AND policyname = 'Users can create their own orders'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can create their own orders" ON orders
            FOR INSERT WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'orders' 
          AND policyname = 'Delivery persons can update assigned orders'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Delivery persons can update assigned orders" ON orders
            FOR UPDATE USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = delivery_person_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- order_items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'order_items' 
          AND policyname = 'Users can view items of their orders'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view items of their orders" ON order_items
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM orders 
                    WHERE orders.id = order_items.order_id 
                    AND (
                        auth.uid()::text = (
                            SELECT auth_user_id::text FROM users WHERE id = orders.user_id
                        )
                        OR 
                        auth.uid()::text = (
                            SELECT auth_user_id::text FROM users WHERE id = orders.delivery_person_id
                        )
                    )
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'order_items' 
          AND policyname = 'Users can insert items to their orders'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can insert items to their orders" ON order_items
            FOR INSERT WITH CHECK (
                EXISTS (
                    SELECT 1 FROM orders 
                    WHERE orders.id = order_items.order_id 
                    AND auth.uid()::text = (
                        SELECT auth_user_id::text FROM users WHERE id = orders.user_id
                    )
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- user_carts
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_carts' 
          AND policyname = 'Users can view their cart'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their cart" ON user_carts
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_carts' 
          AND policyname = 'Users can manage their cart'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can manage their cart" ON user_carts
            FOR ALL USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            ) WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- user_cart_items
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_cart_items' 
          AND policyname = 'Users can view their cart items'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their cart items" ON user_cart_items
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_cart_items' 
          AND policyname = 'Users can manage their cart items'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can manage their cart items" ON user_cart_items
            FOR ALL USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            ) WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- delivery_locations
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'delivery_locations' 
          AND policyname = 'Users can view delivery locations of their orders'
    ) THEN
        EXECUTE $policy$
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
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'delivery_locations' 
          AND policyname = 'Delivery persons can update their locations'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Delivery persons can update their locations" ON delivery_locations
            FOR INSERT WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = delivery_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- notifications
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'notifications' 
          AND policyname = 'Users can view their own notifications'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their own notifications" ON notifications
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'notifications' 
          AND policyname = 'Users can mark their notifications as read'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can mark their notifications as read" ON notifications
            FOR UPDATE USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- social_groups
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'social_groups' 
          AND policyname = 'Users can view public groups and their own groups'
    ) THEN
        EXECUTE $policy$
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
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'social_groups' 
          AND policyname = 'Users can create groups'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can create groups" ON social_groups
            FOR INSERT WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = creator_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- group_members
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'group_members' 
          AND policyname = 'Users can view group members'
    ) THEN
        EXECUTE $policy$
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
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'group_members' 
          AND policyname = 'Users can manage their membership'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can manage their membership" ON group_members
            FOR ALL USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            ) WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- social_posts
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'social_posts' 
          AND policyname = 'Users can view public posts and posts from their groups'
    ) THEN
        EXECUTE $policy$
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
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'social_posts' 
          AND policyname = 'Users can create posts'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can create posts" ON social_posts
            FOR INSERT WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- loyalty_rewards
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'loyalty_rewards' 
          AND policyname = 'Loyalty rewards are publicly readable'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Loyalty rewards are publicly readable" ON loyalty_rewards
            FOR SELECT USING (is_active = true);
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'loyalty_rewards' 
          AND policyname = 'Admins can manage loyalty rewards'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Admins can manage loyalty rewards" ON loyalty_rewards
            FOR ALL USING (
                EXISTS (
                    SELECT 1 FROM users 
                    WHERE auth_user_id = auth.uid() 
                    AND role = 'admin'
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- loyalty_transactions
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'loyalty_transactions' 
          AND policyname = 'Users can view their loyalty transactions'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their loyalty transactions" ON loyalty_transactions
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'loyalty_transactions' 
          AND policyname = 'Admins can manage loyalty transactions'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Admins can manage loyalty transactions" ON loyalty_transactions
            FOR ALL USING (
                EXISTS (
                    SELECT 1 FROM users 
                    WHERE auth_user_id = auth.uid() 
                    AND role = 'admin'
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- reward_redemptions
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'reward_redemptions' 
          AND policyname = 'Users can view their reward redemptions'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their reward redemptions" ON reward_redemptions
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'reward_redemptions' 
          AND policyname = 'Users can manage their reward redemptions'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can manage their reward redemptions" ON reward_redemptions
            FOR ALL USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            ) WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- user_achievements
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_achievements' 
          AND policyname = 'Users can view their achievements'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their achievements" ON user_achievements
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_achievements' 
          AND policyname = 'Users can update their achievements'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can update their achievements" ON user_achievements
            FOR ALL USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            ) WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- user_challenges
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_challenges' 
          AND policyname = 'Users can view their challenges'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their challenges" ON user_challenges
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_challenges' 
          AND policyname = 'Users can update their challenges'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can update their challenges" ON user_challenges
            FOR ALL USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            ) WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- badges
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'badges' 
          AND policyname = 'Badges are publicly readable'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Badges are publicly readable" ON badges
            FOR SELECT USING (is_active = true);
        $policy$;
    END IF;

    -- user_badges
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_badges' 
          AND policyname = 'Users can view their badges'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their badges" ON user_badges
            FOR SELECT USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_badges' 
          AND policyname = 'Users can update their badges'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can update their badges" ON user_badges
            FOR ALL USING (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            ) WITH CHECK (
                auth.uid()::text = (
                    SELECT auth_user_id::text FROM users WHERE id = user_id
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- promotions
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'promotions' 
          AND policyname = 'Promotions are publicly readable'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Promotions are publicly readable" ON promotions
            FOR SELECT USING (is_active = true);
        $policy$;
    END IF;

    -- analytics_events
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'analytics_events' 
          AND policyname = 'Admins can view analytics'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Admins can view analytics" ON analytics_events
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM users 
                    WHERE auth_user_id = auth.uid() 
                    AND role = 'admin'
                )
                OR auth.role() = 'service_role'
            );
        $policy$;
    END IF;

    -- saved_forms
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'saved_forms' 
          AND policyname = 'Users can view their own saved forms'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their own saved forms" ON saved_forms
            FOR SELECT USING (auth.uid()::text = user_id::text OR auth.role() = 'service_role');
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'saved_forms' 
          AND policyname = 'Users can create their own saved forms'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can create their own saved forms" ON saved_forms
            FOR INSERT WITH CHECK (auth.uid()::text = user_id::text OR auth.role() = 'service_role');
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'saved_forms' 
          AND policyname = 'Users can update their own saved forms'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can update their own saved forms" ON saved_forms
            FOR UPDATE USING (auth.uid()::text = user_id::text OR auth.role() = 'service_role');
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'saved_forms' 
          AND policyname = 'Users can delete their own saved forms'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can delete their own saved forms" ON saved_forms
            FOR DELETE USING (auth.uid()::text = user_id::text OR auth.role() = 'service_role');
        $policy$;
    END IF;

    -- validation_history
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'validation_history' 
          AND policyname = 'Users can view their own validation history'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can view their own validation history" ON validation_history
            FOR SELECT USING (auth.uid()::text = user_id::text OR auth.role() = 'service_role');
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'validation_history' 
          AND policyname = 'Users can create their own validation history'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can create their own validation history" ON validation_history
            FOR INSERT WITH CHECK (auth.uid()::text = user_id::text OR auth.role() = 'service_role');
        $policy$;
    END IF;

    -- group_payments
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'group_payments'
          AND policyname = 'Users can view their group payments'
    ) THEN
        EXECUTE $policy$
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
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'group_payments'
          AND policyname = 'Users can create their group payments'
    ) THEN
        EXECUTE $policy$
        CREATE POLICY "Users can create their group payments" ON group_payments
            FOR INSERT WITH CHECK (
                auth.role() = 'service_role'
                OR EXISTS (
                    SELECT 1 FROM users u
                    WHERE u.id = initiated_by
                      AND u.auth_user_id::text = auth.uid()::text
                )
            );
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'group_payments'
          AND policyname = 'Users can update their group payments'
    ) THEN
        EXECUTE $policy$
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
        $policy$;
    END IF;

    -- group_payment_participants
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'group_payment_participants'
          AND policyname = 'Users can view group payment participants'
    ) THEN
        EXECUTE $policy$
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
        $policy$;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'group_payment_participants'
          AND policyname = 'Users can manage group payment participants'
    ) THEN
        EXECUTE $policy$
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
        $policy$;
    END IF;

END $$;

