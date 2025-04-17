WITH submissions AS (
  SELECT * 
  FROM submission 
  WHERE last_action_id IS NULL
),
last_action_logs AS (
  SELECT DISTINCT ON (s.id) al.id AS aid, s.id AS sid 
  FROM action_log al
  JOIN submissions s ON al.action_logs_id = s.id
  ORDER BY s.id, al.action_date DESC
)
UPDATE submission s
SET last_action_id = las.aid
FROM last_action_logs las
WHERE s.id = las.sid;

