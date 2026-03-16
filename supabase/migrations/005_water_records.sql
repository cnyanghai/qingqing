-- 浇水记录表
-- 注意：增加classroom_id列以避免教师RLS策略查profiles表导致递归（参考002/004经验）
CREATE TABLE water_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_student_id UUID REFERENCES profiles(id) NOT NULL,
  to_student_id UUID REFERENCES profiles(id) NOT NULL,
  classroom_id UUID REFERENCES classrooms(id) NOT NULL,
  watered_at DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  -- 每人每天只能给同一个人浇一次水
  UNIQUE(from_student_id, to_student_id, watered_at)
);

CREATE INDEX idx_water_from ON water_records(from_student_id);
CREATE INDEX idx_water_to ON water_records(to_student_id);
CREATE INDEX idx_water_date ON water_records(watered_at);
CREATE INDEX idx_water_classroom ON water_records(classroom_id);

-- RLS
ALTER TABLE water_records ENABLE ROW LEVEL SECURITY;

-- 学生可以创建浇水记录（只能以自己的名义）
CREATE POLICY "Students can insert own water records"
  ON water_records FOR INSERT WITH CHECK (auth.uid() = from_student_id);

-- 学生可以读取与自己相关的浇水记录（给别人浇的 + 别人给自己浇的）
CREATE POLICY "Students can read own water records"
  ON water_records FOR SELECT USING (
    auth.uid() = from_student_id OR auth.uid() = to_student_id
  );

-- 教师可以看到班级的浇水记录（通过classroom_id关联classrooms表，不查profiles避免递归）
CREATE POLICY "Teachers can read class water records"
  ON water_records FOR SELECT USING (
    classroom_id IN (
      SELECT id FROM classrooms WHERE teacher_id = auth.uid()
    )
  );
