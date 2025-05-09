ALTER TABLE submission ADD COLUMN last_action_id bigint;
ALTER TABLE submission ADD CONSTRAINT fk2c4y6bgj1x6np516kh15ou9x0 FOREIGN KEY (last_action_id) REFERENCES action_log(id);
GRANT USAGE, SELECT on all sequences in schema public to vireo;
