#UNKNOWN IN 4.2.8
DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    WITH constraint_info AS (
        SELECT
            conname AS constraint_name,
            conrelid::regclass AS table_name,
            ARRAY(SELECT a.attname
                  FROM unnest(conkey) AS k
                  JOIN pg_attribute AS a ON a.attnum = k AND a.attrelid = conrelid) AS column_names
        FROM
            pg_constraint
        WHERE
            conrelid = 'submission_list_column'::regclass
    ),
    constraints AS (
        SELECT
            ci.constraint_name,
            ci.table_name
        FROM
            constraint_info ci
        WHERE
            ci.column_names::text[] @> ARRAY['title', 'predicate', 'input_type_id']::text[]
    )
    SELECT constraint_name INTO v_constraint_name FROM constraints;

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', 'submission_list_column', v_constraint_name);
    END IF;

    EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I UNIQUE (%I)', 'submission_list_column', v_constraint_name, 'title');
END $$;
