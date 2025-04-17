DO $$
  DECLARE
    LE_id int;
BEGIN
  SELECT id INTO LE_id FROM submission_list_column WHERE title = 'Last Event';
  IF LE_id IS NULL THEN
    INSERT INTO submission_list_column (id,title,input_type_id) VALUES(DEFAULT,'Last Event',1);
    INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) VALUES(currval('submission_list_column_id_seq'),'lastAction',0);
    INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) VALUES(currval('submission_list_column_id_seq'),'entry',1);
  ELSE
    RAISE NOTICE 'already exists';
    UPDATE submission_list_column_value_path SET value_path = 'lastAction' FROM (SELECT id FROM submission_list_column WHERE title = 'Last Event') AS find_slc_id  WHERE submission_list_column_id = find_slc_id.id AND value_path_order = 0;
    INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) (SELECT id,'entry',1 FROM submission_list_column WHERE title = 'Last Event') ON CONFLICT (submission_list_column_id,value_path_order) DO NOTHING;
  END IF;
END$$;
