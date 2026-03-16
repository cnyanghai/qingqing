-- 006_comments.sql
-- 留言系统: 浇水留言 + 同学留言板

-- 1. 给 water_records 表添加 message 字段
ALTER TABLE water_records ADD COLUMN IF NOT EXISTS message TEXT;

-- 2. 新建留言表
CREATE TABLE student_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID REFERENCES profiles(id) NOT NULL,
  target_student_id UUID REFERENCES profiles(id) NOT NULL,
  classroom_id UUID REFERENCES classrooms(id) NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_messages_target ON student_messages(target_student_id);
CREATE INDEX idx_messages_classroom ON student_messages(classroom_id);
CREATE INDEX idx_messages_created ON student_messages(created_at);

-- RLS
ALTER TABLE student_messages ENABLE ROW LEVEL SECURITY;

-- 学生可以发送留言（只能以自己的名义）
CREATE POLICY "Students can insert own messages"
  ON student_messages FOR INSERT WITH CHECK (auth.uid() = author_id);

-- 同班同学可以看到彼此的留言（通过classroom_id，不直接查profiles避免递归）
CREATE POLICY "Classmates can read class messages"
  ON student_messages FOR SELECT USING (
    classroom_id IN (
      SELECT c.id FROM classrooms c
      INNER JOIN profiles p ON p.classroom_id = c.id
      WHERE p.id = auth.uid()
    )
  );

-- 学生可以删除自己发的留言
CREATE POLICY "Students can delete own messages"
  ON student_messages FOR DELETE USING (auth.uid() = author_id);

-- 教师可以看到班级留言
CREATE POLICY "Teachers can read class messages"
  ON student_messages FOR SELECT USING (
    classroom_id IN (
      SELECT id FROM classrooms WHERE teacher_id = auth.uid()
    )
  );

-- 教师可以删除班级内的留言（管理权）
CREATE POLICY "Teachers can delete class messages"
  ON student_messages FOR DELETE USING (
    classroom_id IN (
      SELECT id FROM classrooms WHERE teacher_id = auth.uid()
    )
  );
