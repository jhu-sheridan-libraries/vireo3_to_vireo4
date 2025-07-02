DELETE FROM deposit_location WHERE id>0;
ALTER SEQUENCE deposit_location_id_seq RESTART WITH 1;
DELETE FROM embargo WHERE guarantor = 'DEFAULT' AND name = 'None' AND description = 'The work will be published after approval.';