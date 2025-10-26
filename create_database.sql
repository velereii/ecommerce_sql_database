-- Database: ecommerce_platform_db
-- DROP DATABASE IF EXISTS ecommerce_platform_db;


-- Реализация DDL скриптов по логической и физической моделям БД.

CREATE DATABASE ecommerce_platform_db
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Russian_Russia.1251'
    LC_CTYPE = 'Russian_Russia.1251'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

SET client_encoding TO 'UTF8';
SELECT current_database();

CREATE TYPE gender_type AS ENUM ('male', 'female');
CREATE TYPE status_type AS ENUM ('paid', 'shipped', 'delivered');
CREATE TYPE device_type AS ENUM ('desktop', 'mobile');

CREATE TABLE client (
    id bigserial PRIMARY KEY,
    first_name varchar(35) NOT NULL,
    last_name varchar(35) NOT NULL,
    email varchar(320),
    phone_number varchar(12) NOT NULL,
    gender gender_type NOT NULL,
    birth_date date NOT NULL,
    reg_date date NOT NULL,
    newsletter_is_active boolean NOT NULL
);

CREATE TABLE city (
    id serial PRIMARY KEY,
    name varchar(35) NOT NULL,
	region varchar(320) NOT NULL
);

CREATE TABLE orders (
    id bigserial NOT NULL,
    client_id bigint NOT NULL,
    order_date timestamptz NOT NULL,
    status status_type NOT NULL,
    city_id int NOT NULL,
    delivery_adress text NOT NULL,
    delivery_date timestamptz NOT NULL,
	PRIMARY KEY(id),
	FOREIGN KEY(client_id) REFERENCES client(id),
	FOREIGN KEY(city_id) REFERENCES city(id)
);

CREATE TABLE warehouse (
    id serial NOT NULL,
    name varchar(320) NOT NULL,
	city_id int NOT NULL,
	PRIMARY KEY(id),
	FOREIGN KEY(city_id) REFERENCES city(id)
);

CREATE TABLE brand (
	id serial PRIMARY KEY,
	name varchar(320) NOT NULL,
	country varchar(320),
	supplier varchar(320)
);

CREATE TABLE category (
	id serial PRIMARY KEY,
	name varchar(35) NOT NULL,
	description text
);

CREATE TABLE product (
	id bigserial NOT NULL,
	name varchar(320) NOT NULL,
	category_id int NOT NULL,
	brand_id int NOT NULL,
	current_price float NOT NULL,
	PRIMARY KEY(id),
	FOREIGN KEY(category_id) REFERENCES category(id),
	FOREIGN KEY(brand_id) REFERENCES brand(id)
);

CREATE TABLE review (
	id bigserial NOT NULL,
	product_id bigint NOT NULL,
	client_id bigint NOT NULL,
	rating int NOT NULL CHECK (rating BETWEEN 1 AND 5),
	review_text text,
	created_at timestamptz NOT NULL,
	PRIMARY KEY(id),
	FOREIGN KEY(product_id) REFERENCES product(id),
	FOREIGN KEY(client_id) REFERENCES client(id)
);

CREATE TABLE session (
	id bigserial NOT NULL,
	client_id bigint NOT NULL,
	start_time timestamptz NOT NULL,
	end_time timestamptz NOT NULL,
	device_type device_type NOT NULL,
	PRIMARY KEY(id),
	FOREIGN KEY(client_id) REFERENCES client(id)
);

CREATE TABLE order_item (
	order_id bigint NOT NULL,
	product_id bigint NOT NULL,
	quantity int NOT NULL CHECK(quantity > 0),
	unit_price float NOT NULL,
	PRIMARY KEY(order_id, product_id),
	FOREIGN KEY(order_id) REFERENCES orders(id),
	FOREIGN KEY(product_id) REFERENCES product(id)
);

CREATE TABLE inventory (
	warehouse_id int NOT NULL,
	product_id bigint NOT NULL,
	quantity int NOT NULL,
	last_update timestamptz NOT NULL,
	PRIMARY KEY(warehouse_id, product_id),
	FOREIGN KEY(warehouse_id) REFERENCES warehouse(id),
	FOREIGN KEY(product_id) REFERENCES product(id)
);

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema');



-- Создание оптимального набора индексов для ускорения основных запросов и связей между таблицами

CREATE INDEX idx_orders_client_id ON orders(client_id);
CREATE INDEX idx_product_category_id ON product(category_id);
CREATE INDEX idx_product_brand_id ON product(brand_id);
CREATE INDEX idx_review_product_id ON review USING hash (product_id);
CREATE INDEX idx_session_client_id ON session USING hash (client_id);
CREATE INDEX idx_inventory_product_id ON inventory(product_id);

SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY tablename;



-- Реализация DML скриптов. Заполнение таблиц случайными данными.

-- Таблица client
INSERT INTO client (first_name, last_name, email, phone_number, gender, birth_date, reg_date, newsletter_is_active)
SELECT
    -- случайное имя
    (ARRAY[
        'Anna','Maria','Elena','Olga','Natalia','Irina','Victoria',
        'Alex','Ivan','Dmitry','Nikita','Pavel','Sergey','Andrey'
    ])[floor(random()*14 + 1)] AS first_name,

    -- случайная фамилия
    INITCAP(regexp_replace(substr(md5(random()::text), 1, 15), '[^A-Za-z]', '', 'g')) || 'ov' AS last_name,
    
    -- email на основе имени
    email = LOWER(first_name || '.' || last_name || '@' ||
    (ARRAY['gmail.com', 'yandex.ru', 'outlook.com', 'mail.ru'])[floor(random()*4 + 1)]) AS email,
    
    -- случайный 12-значный номер телефона
    '+7' || LPAD((floor(random()*10000000000))::text, 10, '0') AS phone_number,
    
    -- случайный пол
    (ARRAY['male', 'female'])[floor(random()*2 + 1)]::gender_type AS gender,
    
    -- дата рождения от 1970 до 2007
    DATE '1970-01-01' + (random() * (DATE '2007-01-01' - DATE '1970-01-01'))::int AS birth_date,
    
    -- дата регистрации за последние 3 года
    (NOW() - (random() * INTERVAL '3 years'))::date AS reg_date,
    
    -- активна ли рассылка
    (random() < 0.5) AS newsletter_is_active
FROM generate_series(1, 1000);


-- Таблица city
INSERT INTO city (name, region)
VALUES
	('Москва', 'Центральный'),
    ('Санкт-Петербург', 'Северо-Западный'),
    ('Нижний Новгород', 'Приволжский'),
    ('Калуга', 'Центральный');


-- Таблица orders
INSERT INTO orders (client_id, order_date, status, city_id, delivery_adress, delivery_date)
SELECT
    -- случайный клиент из существующих
    floor(random() * 1000 + 1)::bigint AS client_id,

    -- дата заказа за последние 3 года
    NOW() - (random() * INTERVAL '3 years') AS order_date,

    -- случайный статус
    CASE
    	WHEN random() < 0.8 THEN 'delivered'::status_type
    	WHEN random() < 0.9 THEN 'shipped'::status_type
    	ELSE 'paid'::status_type
	END AS status,

    -- случайный город
    (ARRAY[1,2,3,4])[floor(random()*4 + 1)] AS city_id,

    -- случайный адрес
    'ул. ' || INITCAP(substr(md5(random()::text), 1, 8)) || ', д. ' || (floor(random()*200 + 1))::int AS delivery_adress,

    -- дата доставки
    NOW() - (random() * INTERVAL '2 years') + (floor(random()*10 + 1) || ' days')::interval AS delivery_date
FROM generate_series(1, 1500);


-- Таблица warehouse
INSERT INTO warehouse (name, city_id)
VALUES
    ('Склад м. Римская', 1),
    ('Склад м. Борисово', 1),
    ('Склад г. Санкт-Петербург', 2),
    ('Склад г. Нижний Новгород', 3),
    ('Склад г. Калуга', 4);


-- Таблица brand
INSERT INTO brand (name, country, supplier)
VALUES
    ('BQ', 'Россия', 'BQ Company'),
    ('Яндекс', 'Россия', 'ООО Яндекс'),
    ('Xiaomi', 'Китай', 'X1 Retailer'),
    ('Samsung', 'Вьетнам', 'X2 Retailer'),
    ('teXet', 'Россия', 'teXet Electronics Ltd.');


-- Таблица category
INSERT INTO category (name, description)
VALUES
    ('Смартфоны', 'Смартфоны.'),
    ('Ноутбуки', 'Ноутбуки.'),
    ('Планшеты', 'Планшеты.'),
    ('Аудио', 'Наушники, колонки и другие аудиоустройства.'),
    ('Аксессуары', 'Чехлы, зарядные устройства, кабели и прочие вспомогательные товары.');


-- Таблица product
INSERT INTO product (name, category_id, brand_id, current_price)
SELECT
    -- случайное название продукта
    INITCAP(substr(md5(random()::text), 1, 6)),

    -- случайная категория из существующих
    (ARRAY[1,2,3,4,5])[floor(random()*5 + 1)],

    -- случайный бренд из существующих
    (ARRAY[1,2,3,4,5])[floor(random()*5 + 1)]d,

    -- случайная цена от 5000 до 150000 рублей
    round((5000 + random() * 145000)::numeric, 2)
FROM generate_series(1,50);


-- Таблица review
INSERT INTO review (product_id, client_id, rating, review_text, created_at)
SELECT
    -- случайный продукт
    (floor(random() * 50 + 1))::int,

    -- случайный клиент
    (floor(random() * 1000 + 1))::int,

    -- рейтинг от 1 до 5
    (floor(random() * 5 + 1))::int,

    -- случайный текст отзыва
    INITCAP(substr(md5(random()::text), 1, 20)),

    -- дата создания за последние 3 года
    NOW() - (random() * INTERVAL '3 years')
FROM generate_series(1,150);


-- Таблица review
INSERT INTO session (client_id, start_time, end_time, device_type)
SELECT
    -- случайный клиент
    floor(random() * 1000 + 1)::bigint,

    -- случайное время начала сессии за последние 3 года
    NOW() - (random() * INTERVAL '3 years') AS start_time,

    -- время окончания сессии: от 5 минут до 3 часов после начала
    start_time + ((5 + random() * 175) || ' minutes')::interval,

    -- случайный тип устройства
    (ARRAY['desktop','mobile'])[(floor(random()*2 + 1)::int)]::device_type
FROM generate_series(1,200);


-- Таблица order_item
INSERT INTO order_item (order_id, product_id, quantity, unit_price)
WITH base AS (
    -- первый проход: каждый order_id встречается хотя бы один раз
    SELECT
        id AS order_id,
        (floor(random() * 40 + 1))::int AS product_id,
        (floor(random() * 5 + 1))::int AS quantity
    FROM orders
),
extra AS (
    -- дополнительные 100 строк
    SELECT
        (floor(random() * 1000 + 1))::int AS order_id,
        (40 + floor(random() * 10 + 1))::int AS product_id,
        (floor(random() * 5 + 1))::int AS quantity
    FROM generate_series(1,100)
),
united AS (SELECT * FROM base
	UNION
	SELECT * FROM extra)
SELECT u.order_id, u.product_id, u.quantity, p.current_price
FROM united u
JOIN product p ON u.product_id = p.id


-- Таблица inventory
INSERT INTO inventory (warehouse_id, product_id, quantity, last_update)
SELECT
    w.id AS warehouse_id,
    p.id AS product_id,
    (floor(random() * 100 + 1))::int AS quantity,
    NOW() - (random() * INTERVAL '30 days') AS last_update -- случайная дата последнего обновления за последний месяц
FROM warehouse w
CROSS JOIN product p;
