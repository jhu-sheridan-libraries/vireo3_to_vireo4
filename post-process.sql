DELETE FROM deposit_location WHERE id>0;
ALTER SEQUENCE deposit_location_id_seq RESTART WITH 1;