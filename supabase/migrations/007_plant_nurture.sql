-- 玩家植物实例表（每种一颗）
CREATE TABLE player_plants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES profiles(id) NOT NULL,
  plant_key TEXT NOT NULL,         -- 植物品种key（如'violet'）
  shelf_index INT NOT NULL,        -- 架子位置（0起始）
  slot_index INT NOT NULL,         -- 格子位置（0起始）
  level INT DEFAULT 1,             -- 当前等级（1-5对应5个成长阶段）
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(student_id, shelf_index, slot_index)  -- 每个位置只能放一株
);

CREATE INDEX idx_player_plants_student ON player_plants(student_id);

-- 阳光值存储（加到profiles表）
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS sunshine INT DEFAULT 0;

-- RLS
ALTER TABLE player_plants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students CRUD own plants"
  ON player_plants FOR ALL USING (auth.uid() = student_id);

-- 同学可以看到彼此的植物（用于班级花园浏览）
CREATE POLICY "Classmates can read plants"
  ON player_plants FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM classrooms c
      INNER JOIN profiles p ON p.classroom_id = c.id
      WHERE p.id = auth.uid()
        AND c.id IN (
          SELECT p2.classroom_id FROM profiles p2 WHERE p2.id = player_plants.student_id
        )
    )
  );

-- 教师可以看到班级植物
CREATE POLICY "Teachers can read class plants"
  ON player_plants FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM classrooms c
      INNER JOIN profiles p ON p.classroom_id = c.id
      WHERE c.teacher_id = auth.uid()
        AND p.id = player_plants.student_id
    )
  );
