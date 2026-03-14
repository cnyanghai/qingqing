-- 允许每天多次打卡
-- 注意：约束名由PostgreSQL自动生成，格式为 {表名}_{列1}_{列2}_key
-- 如约束名不匹配，先用以下查询确认：
-- SELECT conname FROM pg_constraint WHERE conrelid = 'checkins'::regclass AND contype = 'u';
ALTER TABLE checkins DROP CONSTRAINT IF EXISTS checkins_student_id_checked_at_key;
