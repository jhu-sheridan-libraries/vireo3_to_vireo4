
#INSERT INTO submission_list_column (id,predicate,title,input_type_id) VALUES(DEFAULT,'submission_type','Submission Type (List)',1);
#INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) VALUES(currval('submission_list_column_id_seq'),'submissionTypes',0);
#INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) VALUES(currval('submission_list_column_id_seq'),'name',1);
DO $$
  DECLARE
    LE_id int;
BEGIN
  SELECT id INTO LE_id FROM submission_list_column WHERE title = 'Submission Type (List)';
  IF LE_id IS NULL THEN
    INSERT INTO submission_list_column (id,predicate,title,input_type_id) VALUES(DEFAULT,'submission_type','Submission Type (List)',1);
    INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) VALUES(currval('submission_list_column_id_seq'),'submissionTypes',0);
    INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) VALUES(currval('submission_list_column_id_seq'),'name',1);
  ELSE
    RAISE NOTICE 'already exists';
    UPDATE submission_list_column SET predicate = 'submission_type' WHERE id = LE_id;
    INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) (SELECT id,'submissionTypes',0 FROM submission_list_column WHERE title = 'Submission Type (List)') ON CONFLICT (submission_list_column_id,value_path_order) DO NOTHING;
    INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) (SELECT id,'name',1 FROM submission_list_column WHERE title = 'Submission Type (List)') ON CONFLICT (submission_list_column_id,value_path_order) DO NOTHING;
  END IF;
END$$;

#INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) (LE_id,'submissionTypes',0) ON CONFLICT (submission_list_column_id,value_path_order) DO NOTHING;
#INSERT INTO submission_list_column_value_path (submission_list_column_id,value_path,value_path_order) (LE_id,'name',1 FROM submission_list_column) ON CONFLICT (submission_list_column_id,value_path_order) DO NOTHING;
