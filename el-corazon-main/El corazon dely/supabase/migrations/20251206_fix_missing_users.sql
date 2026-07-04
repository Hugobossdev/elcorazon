-- Fix missing users in public.users table based on auth.users
-- This ensures all authenticated users have a public profile
-- Run this in Supabase SQL Editor if you encounter "Key (delivery_id)=(...) is not present in table users"

INSERT INTO public.users (
  auth_user_id, 
  email, 
  name, 
  role, 
  created_at, 
  updated_at, 
  loyalty_points, 
  badges, 
  is_online, 
  is_active
)
SELECT 
  au.id, 
  au.email, 
  COALESCE(au.raw_user_meta_data->>'name', 'Utilisateur'), 
  COALESCE(au.raw_user_meta_data->>'role', 'client'), 
  au.created_at, 
  au.last_sign_in_at,
  0,
  '{}'::text[], -- Empty array for badges
  false,
  true
FROM auth.users au
WHERE NOT EXISTS (
  SELECT 1 FROM public.users pu WHERE pu.auth_user_id = au.id
);

