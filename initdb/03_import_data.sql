\connect delivery
COPY couriers FROM '/docker-entrypoint-initdb.d/couriers.csv' DELIMITER ',' CSV HEADER;
COPY users FROM '/docker-entrypoint-initdb.d/users.csv' DELIMITER ',' CSV HEADER;
COPY products FROM '/docker-entrypoint-initdb.d/products.csv' DELIMITER ',' CSV HEADER;
COPY orders FROM '/docker-entrypoint-initdb.d/orders.csv' DELIMITER ',' CSV HEADER;
COPY courier_actions FROM '/docker-entrypoint-initdb.d/courier_actions.csv' DELIMITER ',' CSV HEADER;
COPY user_actions FROM '/docker-entrypoint-initdb.d/user_actions.csv' DELIMITER ',' CSV HEADER;
