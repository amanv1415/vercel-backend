-- Supabase Database Schema for Matty Design Tool
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================
-- DESIGNS TABLE
-- Stores all user designs with canvas data
-- ================================================
CREATE TABLE IF NOT EXISTS designs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL DEFAULT 'Untitled Design',
  canvas_data JSONB NOT NULL DEFAULT '{"items": [], "canvasBackground": "#ffffff"}'::jsonb,
  thumbnail TEXT, -- Base64 or URL to design thumbnail
  width INTEGER DEFAULT 800,
  height INTEGER DEFAULT 600,
  is_public BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================================
-- USER PROFILES TABLE
-- Extended user information beyond auth.users
-- ================================================
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  website TEXT,
  total_designs INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================================
-- DESIGN SHARES TABLE
-- Track shared designs and collaborators
-- ================================================
CREATE TABLE IF NOT EXISTS design_shares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  design_id UUID REFERENCES designs(id) ON DELETE CASCADE NOT NULL,
  shared_by UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  shared_with UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  share_token TEXT UNIQUE, -- For public sharing
  permission TEXT CHECK (permission IN ('view', 'edit')) DEFAULT 'view',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================================
-- DESIGN TEMPLATES TABLE
-- Store reusable design templates
-- ================================================
CREATE TABLE IF NOT EXISTS design_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT, -- e.g., 'social-media', 'presentation', 'logo'
  canvas_data JSONB NOT NULL,
  thumbnail TEXT,
  is_featured BOOLEAN DEFAULT false,
  uses_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================================
-- INDEXES for Performance
-- ================================================
CREATE INDEX IF NOT EXISTS idx_designs_user_id ON designs(user_id);
CREATE INDEX IF NOT EXISTS idx_designs_created_at ON designs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_designs_updated_at ON designs(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_design_shares_design_id ON design_shares(design_id);
CREATE INDEX IF NOT EXISTS idx_design_shares_shared_with ON design_shares(shared_with);
CREATE INDEX IF NOT EXISTS idx_design_templates_category ON design_templates(category);

-- ================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ================================================

-- Enable RLS on all tables
ALTER TABLE designs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE design_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE design_templates ENABLE ROW LEVEL SECURITY;

-- ================================================
-- DESIGNS POLICIES
-- ================================================

-- Users can view their own designs
CREATE POLICY "Users can view own designs"
  ON designs FOR SELECT
  USING (auth.uid() = user_id);

-- Users can view public designs
CREATE POLICY "Anyone can view public designs"
  ON designs FOR SELECT
  USING (is_public = true);

-- Users can view designs shared with them
CREATE POLICY "Users can view shared designs"
  ON designs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM design_shares
      WHERE design_shares.design_id = designs.id
      AND design_shares.shared_with = auth.uid()
    )
  );

-- Users can insert their own designs
CREATE POLICY "Users can insert own designs"
  ON designs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own designs
CREATE POLICY "Users can update own designs"
  ON designs FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can update shared designs with edit permission
CREATE POLICY "Users can update shared designs with edit permission"
  ON designs FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM design_shares
      WHERE design_shares.design_id = designs.id
      AND design_shares.shared_with = auth.uid()
      AND design_shares.permission = 'edit'
    )
  );

-- Users can delete their own designs
CREATE POLICY "Users can delete own designs"
  ON designs FOR DELETE
  USING (auth.uid() = user_id);

-- ================================================
-- USER PROFILES POLICIES
-- ================================================

-- Anyone can view user profiles
CREATE POLICY "Anyone can view user profiles"
  ON user_profiles FOR SELECT
  USING (true);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile"
  ON user_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = id);

-- ================================================
-- DESIGN SHARES POLICIES
-- ================================================

-- Users can view shares for their designs
CREATE POLICY "Users can view shares for own designs"
  ON design_shares FOR SELECT
  USING (
    auth.uid() = shared_by OR auth.uid() = shared_with
  );

-- Users can create shares for their designs
CREATE POLICY "Users can create shares for own designs"
  ON design_shares FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM designs
      WHERE designs.id = design_id
      AND designs.user_id = auth.uid()
    )
  );

-- Users can delete shares for their designs
CREATE POLICY "Users can delete shares for own designs"
  ON design_shares FOR DELETE
  USING (auth.uid() = shared_by);

-- ================================================
-- DESIGN TEMPLATES POLICIES
-- ================================================

-- Anyone can view templates
CREATE POLICY "Anyone can view templates"
  ON design_templates FOR SELECT
  USING (true);

-- Authenticated users can create templates
CREATE POLICY "Authenticated users can create templates"
  ON design_templates FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Users can update their own templates
CREATE POLICY "Users can update own templates"
  ON design_templates FOR UPDATE
  USING (auth.uid() = created_by);

-- Users can delete their own templates
CREATE POLICY "Users can delete own templates"
  ON design_templates FOR DELETE
  USING (auth.uid() = created_by);

-- ================================================
-- FUNCTIONS
-- ================================================

-- Function to automatically create user profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id, username, full_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at on designs
DROP TRIGGER IF EXISTS update_designs_updated_at ON designs;
CREATE TRIGGER update_designs_updated_at
  BEFORE UPDATE ON designs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to auto-update updated_at on user_profiles
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update user profile design count
CREATE OR REPLACE FUNCTION update_user_design_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE user_profiles
    SET total_designs = total_designs + 1
    WHERE id = NEW.user_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE user_profiles
    SET total_designs = GREATEST(0, total_designs - 1)
    WHERE id = OLD.user_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update design count
DROP TRIGGER IF EXISTS update_design_count ON designs;
CREATE TRIGGER update_design_count
  AFTER INSERT OR DELETE ON designs
  FOR EACH ROW EXECUTE FUNCTION update_user_design_count();

-- ================================================
-- STORAGE BUCKET for Design Assets
-- ================================================

-- Create storage bucket for design assets (thumbnails, images)
INSERT INTO storage.buckets (id, name, public)
VALUES ('design-assets', 'design-assets', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policy: Anyone can view public files
CREATE POLICY "Public Access"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'design-assets');

-- Storage policy: Authenticated users can upload
CREATE POLICY "Authenticated users can upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'design-assets'
    AND auth.role() = 'authenticated'
  );

-- Storage policy: Users can update their own files
CREATE POLICY "Users can update own files"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'design-assets'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Storage policy: Users can delete their own files
CREATE POLICY "Users can delete own files"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'design-assets'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ================================================
-- Sample Data (Optional)
-- ================================================

-- You can add sample templates here after creating them
-- INSERT INTO design_templates (title, description, category, canvas_data, is_featured)
-- VALUES (...);
