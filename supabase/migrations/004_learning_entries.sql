-- 学习记录表
CREATE TABLE learning_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES profiles(id) NOT NULL,
  classroom_id UUID REFERENCES classrooms(id) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('book', 'skill')),
  title TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN (
    'reading', 'music', 'sports', 'coding', 'art', 'language', 'science', 'other'
  )),
  status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed')),
  progress INT DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  started_at DATE DEFAULT CURRENT_DATE,
  completed_at DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_learning_student ON learning_entries(student_id);
CREATE INDEX idx_learning_classroom ON learning_entries(classroom_id);
CREATE INDEX idx_learning_type ON learning_entries(type);

-- RLS
ALTER TABLE learning_entries ENABLE ROW LEVEL SECURITY;

-- 学生可以增删改查自己的记录
CREATE POLICY "Students can insert own learning entries"
  ON learning_entries FOR INSERT WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Students can read own learning entries"
  ON learning_entries FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY "Students can update own learning entries"
  ON learning_entries FOR UPDATE USING (auth.uid() = student_id);

CREATE POLICY "Students can delete own learning entries"
  ON learning_entries FOR DELETE USING (auth.uid() = student_id);

-- 同班同学可以看到彼此的记录（全班可见）
-- 注意：不直接查profiles表（会触发RLS递归，参考002_fix_rls_recursion.sql）
-- 通过classrooms表间接定位教室
CREATE POLICY "Classmates can read each other learning entries"
  ON learning_entries FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM classrooms c
      INNER JOIN profiles p ON p.classroom_id = c.id
      WHERE c.id = learning_entries.classroom_id
        AND p.id = auth.uid()
    )
  );

-- 教师可以看到班级学生的记录
CREATE POLICY "Teachers can read class learning entries"
  ON learning_entries FOR SELECT USING (
    classroom_id IN (
      SELECT id FROM classrooms WHERE teacher_id = auth.uid()
    )
  );
