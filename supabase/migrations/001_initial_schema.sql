-- 晴晴 App Phase 0 Database Schema
-- Run this in Supabase Dashboard > SQL Editor

-- Enable trigram extension for fuzzy school name search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================
-- 1. Schools table
-- ============================================
CREATE TABLE schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  province TEXT,
  city TEXT,
  district TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_schools_name ON schools USING gin(name gin_trgm_ops);

-- ============================================
-- 2. Classrooms table
-- ============================================
CREATE TABLE classrooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  teacher_id UUID REFERENCES auth.users(id),
  enrollment_year INT NOT NULL,
  class_number INT NOT NULL,
  join_code CHAR(6) UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_classrooms_join_code ON classrooms(join_code);
CREATE INDEX idx_classrooms_teacher ON classrooms(teacher_id);

-- ============================================
-- 3. Profiles table (students + teachers)
-- ============================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  role TEXT NOT NULL CHECK (role IN ('student', 'teacher')),
  nickname TEXT NOT NULL,
  avatar_key TEXT DEFAULT 'cat',
  classroom_id UUID REFERENCES classrooms(id),
  streak INT DEFAULT 0,
  longest_streak INT DEFAULT 0,
  total_checkins INT DEFAULT 0,
  points INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_profiles_classroom ON profiles(classroom_id);
CREATE INDEX idx_profiles_role ON profiles(role);

-- ============================================
-- 4. Checkins table
-- ============================================
CREATE TABLE checkins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES profiles(id) NOT NULL,
  classroom_id UUID REFERENCES classrooms(id) NOT NULL,
  quadrant TEXT NOT NULL CHECK (quadrant IN ('red', 'yellow', 'green', 'blue')),
  emotion_label TEXT NOT NULL,
  context_tag TEXT NOT NULL CHECK (context_tag IN ('school', 'recess', 'lunch', 'home', 'commute')),
  note TEXT,
  checked_at DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, checked_at)
);
CREATE INDEX idx_checkins_student ON checkins(student_id);
CREATE INDEX idx_checkins_classroom ON checkins(classroom_id);
CREATE INDEX idx_checkins_date ON checkins(checked_at);

-- ============================================
-- 5. Badges table
-- ============================================
CREATE TABLE badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES profiles(id) NOT NULL,
  badge_key TEXT NOT NULL,
  earned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, badge_key)
);
CREATE INDEX idx_badges_student ON badges(student_id);

-- ============================================
-- 6. Row Level Security (RLS)
-- ============================================

-- Profiles: own profile full access, classmates read-only
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Classmates can read each other"
  ON profiles FOR SELECT USING (
    classroom_id IN (SELECT classroom_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "Teachers can read class profiles"
  ON profiles FOR SELECT USING (
    classroom_id IN (SELECT id FROM classrooms WHERE teacher_id = auth.uid())
  );

-- Checkins: students own, teachers read class
ALTER TABLE checkins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can insert own checkins"
  ON checkins FOR INSERT WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Students can read own checkins"
  ON checkins FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY "Teachers can read class checkins"
  ON checkins FOR SELECT USING (
    classroom_id IN (SELECT id FROM classrooms WHERE teacher_id = auth.uid())
  );

-- Badges: students own
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students can read own badges"
  ON badges FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY "Students can insert own badges"
  ON badges FOR INSERT WITH CHECK (auth.uid() = student_id);

-- Schools: public read, authenticated insert
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read schools"
  ON schools FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create schools"
  ON schools FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Classrooms: teachers own, students read joined
ALTER TABLE classrooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read classrooms by join_code"
  ON classrooms FOR SELECT USING (true);

CREATE POLICY "Teachers can create classrooms"
  ON classrooms FOR INSERT WITH CHECK (auth.uid() = teacher_id);

-- ============================================
-- 7. Enable anonymous auth (for students)
-- ============================================
-- Note: Enable "Anonymous Sign-ins" in Supabase Dashboard:
-- Authentication > Providers > Anonymous > Enable
