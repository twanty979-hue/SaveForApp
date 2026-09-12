-- Migration: 007_bank_album_rules.sql
-- Description: Scalable table for user-configurable bank slip album scanner rules with logo URLs

CREATE TABLE IF NOT EXISTS public.bank_album_rules (
    id TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    bank_type TEXT NOT NULL DEFAULT 'other',
    name TEXT NOT NULL,
    app_name TEXT DEFAULT '',
    logo_url TEXT DEFAULT '',
    album_keywords TEXT[] NOT NULL DEFAULT '{}',
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    is_custom BOOLEAN NOT NULL DEFAULT false,
    color_hex TEXT DEFAULT '#00A950',
    priority INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (id, user_id)
);

-- Indexes for efficient querying by user
CREATE INDEX IF NOT EXISTS idx_bank_album_rules_user_id ON public.bank_album_rules (user_id);
CREATE INDEX IF NOT EXISTS idx_bank_album_rules_bank_type ON public.bank_album_rules (bank_type);

-- Row Level Security
ALTER TABLE public.bank_album_rules ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own bank rules
CREATE POLICY "Users can select own bank rules"
    ON public.bank_album_rules
    FOR SELECT
    USING (auth.uid() = user_id);

-- Allow users to insert/update their own bank rules
CREATE POLICY "Users can insert own bank rules"
    ON public.bank_album_rules
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own bank rules"
    ON public.bank_album_rules
    FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own bank rules"
    ON public.bank_album_rules
    FOR DELETE
    USING (auth.uid() = user_id);
