\connect delivery

DROP TABLE IF EXISTS couriers CASCADE;
CREATE TABLE couriers(
	courier_id INT PRIMARY KEY,
	birth_date DATE,
	sex VARCHAR(10)
);

DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users(
	user_id INT PRIMARY KEY,
	birth_date DATE,
	sex VARCHAR(10)
);

DROP TABLE IF EXISTS products CASCADE;
CREATE TABLE products(
	product_id INT PRIMARY KEY,
	name VARCHAR(50),
	price NUMERIC(10, 2)
);


DROP TABLE IF EXISTS orders CASCADE;
CREATE TABLE orders(
	order_id INT PRIMARY KEY,
	creation_time TIMESTAMP,
	product_ids INT[]
);

DROP TABLE IF EXISTS courier_actions;
CREATE TABLE courier_actions(
	courier_id INT,
	order_id INT,
	action VARCHAR(30),
	time TIMESTAMP
);

DROP TABLE IF EXISTS user_actions;
CREATE TABLE user_actions(
	user_id INT,
	order_id INT,
	action VARCHAR(30),
	time TIMESTAMP
)

