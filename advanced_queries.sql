-- 1. Доля категории в общем объёме продаж

SELECT c.name AS category_name,
	ROUND((
		SUM(o.quantity * o.unit_price) / SUM(SUM(o.quantity * o.unit_price)) OVER () )::numeric
		, 2
	) AS share_percent
FROM category c
JOIN product p ON p.category_id = c.id
JOIN order_item o ON o.product_id = p.id
GROUP BY c.name;


-- 2. Продажи брендов с долей рынка внутри категории
-- с использованием оконной функции

SELECT c.name AS category,
	b.name AS brand,
	ROUND((
		SUM(o.quantity * o.unit_price) / 1000000)::numeric
		, 3
	) AS brand_sales_in_million_rub,
	ROUND((
		SUM(o.quantity * o.unit_price) * 100.0 / 
		(SUM(SUM(o.quantity * o.unit_price)) OVER (PARTITION BY c.name)))::numeric
		, 2
	)::text || '%' AS market_share_percent
FROM category c
JOIN product p ON p.category_id = c.id
JOIN brand b ON p.brand_id = b.id
JOIN order_item o ON o.product_id = p.id
GROUP BY c.name, b.name
ORDER BY c.name, b.name;


-- 3. Бренды-лидеры по оценкам покупателей
-- с использованием представления и CTE

CREATE OR REPLACE VIEW top3_brands AS

WITH brand_avg_ratings AS (
	SELECT b.name AS brand,
		ROUND(
			AVG(rating),
			2
		) AS rating
	FROM brand b
	JOIN product p ON p.brand_id = b.id
	JOIN review r ON r.product_id = p.id
	GROUP BY b.name
)
SELECT brand, rating
FROM brand_avg_ratings
ORDER BY rating DESC
LIMIT 3;

SELECT * FROM top3_brands;


-- 4. Динамика продаж по месяцам
-- рекурсивный запрос

WITH RECURSIVE monthly_sales AS (
	SELECT
        date_trunc('month', o.order_date)::date AS month,
        SUM(oi.quantity * oi.unit_price) AS total_sales
    FROM orders o
    JOIN order_item oi ON o.id = oi.order_id
    GROUP BY 1
    ORDER BY 1
),
dif_sales AS (
	SELECT ms.month,
		ROUND(
			(ms.total_sales / 1000000)::numeric,
			2
			) AS monthly_sales_mil,
		0.0 AS diff,
		'0%' AS diff_percent
	FROM monthly_sales ms
	WHERE month = (SELECT MIN(month) FROM monthly_sales)
	
	UNION ALL
	
	SELECT m.month,
		ROUND(
			(m.total_sales / 1000000)::numeric
			, 2) AS monthly_sales_mil,
		ROUND(
			(m.total_sales / 1000000 - d.monthly_sales_mil)::numeric
			, 2) AS diff,
		ROUND(
			(100.0 * (m.total_sales / 1000000 - d.monthly_sales_mil) /
			d.monthly_sales_mil)::numeric
			, 2)::text || '%' AS diff_percent
	FROM monthly_sales m
    JOIN dif_sales d ON m.month = d.month + INTERVAL '1 month'
)
SELECT *
FROM dif_sales
ORDER BY month;
