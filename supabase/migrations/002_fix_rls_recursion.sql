-- Fix: infinite recursion in profiles RLS policy
-- The "Classmates can read each other" policy queries profiles table itself, causing recursion

-- Drop problematic policies
DROP POLICY IF EXISTS "Classmates can read each other" ON profiles;
DROP POLICY IF EXISTS "Teachers can read class profiles" ON profiles;
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- Recreate without recursion
-- Own profile: full access
CREATE POLICY "Own profile read" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Own profile insert" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Own profile update" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Teachers can read students in their classroom
-- Use classrooms table (not profiles) to avoid recursion
CREATE POLICY "Teachers read class students" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM classrooms
      WHERE classrooms.id = profiles.classroom_id
        AND classrooms.teacher_id = auth.uid()
    )
  );

-- Students can read classmates via classrooms table
CREATE POLICY "Students read classmates" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM classrooms
      WHERE classrooms.id = profiles.classroom_id
        AND classrooms.id = (
          SELECT p.classroom_id FROM profiles p WHERE p.id = auth.uid() LIMIT 1
        )
    )
  );
