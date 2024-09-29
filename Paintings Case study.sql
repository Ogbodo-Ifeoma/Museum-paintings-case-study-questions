-- I familarized myself with the columns and values of the tables
-- in the dataset.

SELECT TOP 2 * FROM artist
SELECT TOP 2 * FROM image_link
SELECT TOP 2 * FROM museum
SELECT TOP 2 * FROM work
SELECT TOP 2 * FROM museum_hours
SELECT TOP 2 * FROM canvas_size
SELECT TOP 2 * FROM product_size
SELECT TOP 2 * FROM subject

-- 1. Fetch all the paintings which are not displayed on any museums?
SELECT
	work_id, name
FROM	
	work
WHERE
	museum_id IS NULL

--  2. Are there museums without any paintings?
SELECT *
FROM
	work
WHERE
	work_id IS NULL

--  3. How many paintings have an asking price of more than their regular price?

SELECT 
	COUNT(*)
FROM
	product_size
WHERE
	sale_price > regular_price

--  4. Identify the paintings whose asking price is less than 50% of its regular price

SELECT 
	*
FROM
	product_size
WHERE
	sale_price < (regular_price * 0.5)

--  5. Which canva size costs the most?

WITH mostExpensiveWork AS (
SELECT 
	work_id, size_id, sale_price, RANK() OVER(ORDER BY sale_price DESC) as rank
FROM
	product_size)

SELECT 
	work_id, size_id, sale_price
FROM 
	mostExpensiveWork
WHERE
	rank = 1


-- 6. Delete duplicate records from work, product_size, subject and image_link tables
-- I deleted duplicate records from work and product_size tables 
-- in a seperate file.

WITH duplicates AS (
SELECT
	work_id, url, ROW_NUMBER() OVER(PARTITION BY work_id, url ORDER BY work_id) as row_num
FROM
	image_link)

DELETE FROM
	image_link
WHERE
	work_id IN(
SELECT
	work_id
FROM
	duplicates
WHERE
	row_num > 1)


-- 7. Identify the museums with invalid city information in the given dataset
SELECT *
FROM museum
WHERE city LIKE '%[0-9]' 

SELECT *
FROM museum
WHERE city LIKE '[0-9]%'

-- I changed the values of the invalid city rows to NULL
UPDATE museum
SET city = NULL
WHERE city LIKE '%[0-9]' 

SELECT
	*
FROM 
	museum
WHERE 
	city IS NULL

-- I removed the NULL constraint from the city column
-- so I can alter the column
ALTER TABLE museum
ALTER COLUMN city nvarchar(50) NULL


-- 9. Fetch the top 10 most famous painting subject

-- Most famous by how much the total painting subject cost
-- Most famous by how many copies of the painting subject there is

-- Most famous by how much the total painting subject cost
SELECT
	TOP 10 s.subject,
	COUNT(s.subject) as total_painting_subject,
	SUM(ps.sale_price) as total_subject_sale_price,
	ROW_NUMBER() OVER(ORDER BY SUM(ps.sale_price) DESC)
FROM 
	subject as s
JOIN 
	product_size as ps
ON
	s.work_id = ps.work_id
GROUP BY
	s.subject
ORDER BY
	total_subject_sale_price DESC

-- Most famous by how many copies of the painting subject there is
SELECT
	TOP 10 s.subject,
	COUNT(s.subject) as total_painting_subject
FROM 
	subject as s
JOIN 
	product_size as ps
ON
	s.work_id = ps.work_id
GROUP BY
	s.subject
ORDER BY
	total_painting_subject DESC


-- 10. Identify the museums which are open on both Sunday and Monday. Display 
-- museum name, city

SELECT
	m.name,
	m.city,
	mh.day
FROM
	museum AS m
JOIN
	museum_hours AS mh
ON
	m.museum_id = mh.museum_id

WHERE
	mh.day = 'Sunday'
AND EXISTS
(SELECT
	*
FROM
	museum AS m
JOIN
	museum_hours AS mh
ON
	m.museum_id = mh.museum_id
WHERE
	mh.day = 'Sunday')

--  11. How many museums are open every single day?

SELECT
	museum_id,
	COUNT(day) AS days_of_the_week
FROM
	museum_hours
GROUP BY
	museum_id
HAVING
	COUNT(day) = 7

-- 12. Which are the top 5 most popular museum? (Popularity is defined based on most 
-- no of paintings in a museum)

WITH most_popular_museums AS
 (SELECT
	m.museum_id,
	m.name, 
	COUNT(w.name) as total_paintings,
	ROW_NUMBER() OVER (ORDER BY COUNT(w.name) DESC) as most_popular_museum_no
FROM
	museum AS m
JOIN
	work AS	w
ON
	m.museum_id = w.museum_id
GROUP BY
	m.museum_id, m.name
)
SELECT
	*
FROM
	most_popular_museums
WHERE
	most_popular_museum_no <= 5

-- 13. Who are the top 5 most popular artist? (Popularity is defined based on most no of 
-- paintings done by an artist)

WITH most_popular_artists AS
	(SELECT
	a.artist_id,
	a.full_name,
	COUNT(w.name) AS no_of_paintings,
	DENSE_RANK() OVER(ORDER BY COUNT(w.name) DESC) AS most_popular_artist
FROM
	artist AS a
JOIN
	work AS w
ON
	a.artist_id = w.artist_id
GROUP BY
	a.artist_id, a.full_name)

SELECT 
	*
FROM 
	most_popular_artists
WHERE
	most_popular_artist <= 5



-- 14. Which museum is open for the longest during a day. Dispay museum name, state 
-- and hours open and which day?

WITH museum_hours_duration AS
(SELECT 
	m.name, m.state, 
	DATEDIFF(HOUR, [open], [close]) as hours_opened, [day],
	DENSE_RANK() OVER(ORDER BY DATEDIFF(HOUR, [open], [close]) DESC) AS row_num
FROM 
	museum_hours as mh
JOIN 
	museum as m
ON 
	mh.museum_id = m.museum_id)
SELECT 
	name, state, 
	hours_opened, day
FROM
	museum_hours_duration
WHERE
	row_num = 1

-- 15. Which museum has the most no of most popular painting style?

WITH painting_style AS (
SELECT 
	style,
	COUNT(style) AS no_of_painting_style,
	ROW_NUMBER() OVER(ORDER BY COUNT(style) DESC) AS rnk
FROM
	work
GROUP BY
	style)

SELECT
	TOP 1
	m.museum_id, m.name, w.style,
	COUNT(*) AS no_of_most_popular_style
FROM
	museum AS m
JOIN
	work AS w
ON
	m.museum_id = w.museum_id
JOIN
	painting_style as ps
ON
	ps.style = w.style
GROUP BY
	m.museum_id, m.name, w.style
ORDER BY
	no_of_most_popular_style DESC


-- 16. Identify the artist and the museum where the most expensive
-- painting is placed. Display the artist name, sale_price, painting name, museum 
--name, museum city and canvas label

WITH info AS
(SELECT 
	*,
	RANK() OVER(ORDER BY sale_price) AS least_expensive,
	RANK() OVER(ORDER BY sale_price DESC) AS most_expensive
FROM
	product_size)

SELECT 
	a.full_name, info.sale_price,
	w.name, m.name, m.city, cs.label
FROM
	info
JOIN
	work AS w
ON
	info.work_id = w.work_id
JOIN
	canvas_size AS cs
ON
	info.size_id = cs.size_id
JOIN
	artist AS a
ON	
	w.artist_id = a.artist_id
JOIN
	museum AS m
ON
	w.museum_id = m.museum_id
WHERE
	most_expensive = 1

-- 17. Which country has the 5th highest no of paintings?

WITH country_rating AS
(SELECT 
	m.country, COUNT(w.name) as no_of_painting,
	RANK() OVER(ORDER BY COUNT(w.name) DESC) as rnk
FROM
	museum as m
JOIN
	work as w
ON
	m.museum_id = w.museum_id
GROUP BY
	m.country)

SELECT
	*
FROM
	country_rating
WHERE
	rnk = 5


-- 18. Which are the 3 most popular and 3 least popular painting styles?

WITH painting_style AS
(SELECT
	style,
	COUNT(style) as count_of_painting_style,
	ROW_NUMBER() OVER(ORDER BY COUNT(style) DESC) AS most_popular,
	ROW_NUMBER() OVER(ORDER BY COUNT(style)) AS least_popular
FROM
	work
GROUP BY
	style)

SELECT *
FROM
	painting_style
WHERE
	most_popular <= 3
OR
	least_popular <= 3
ORDER BY
	count_of_painting_style DESC

-- 19. Which artist has the most no of Portraits paintings outside USA?. Display artist
-- name, no of paintings and the artist nationality

SELECT 
	TOP 1
	a.full_name,
	COUNT(s.subject) AS portraits_count,
	a.nationality
FROM
	subject AS s
JOIN
	work AS	w
ON
	s.work_id = w.work_id
JOIN
	artist AS a
ON
	a.artist_id = w.artist_id
WHERE
	subject = 'Portraits'
AND
	nationality != 'American'
GROUP BY
	a.full_name, a.nationality
ORDER BY
	portraits_count DESC