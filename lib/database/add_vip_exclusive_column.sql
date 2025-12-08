-- Add is_vip_exclusive column to menu_items table
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS is_vip_exclusive BOOLEAN DEFAULT FALSE;

