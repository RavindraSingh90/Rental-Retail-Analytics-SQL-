
USE [MarketingAnalytics];

-- TASK 1 - Setup relationship between tables using PK and FK relationship [Both UI + Alter queries] 
--	Using GUI
		-- STEP 1 - import flat files
		-- STEP 2 - Set primary keys first using GUI, by right click on that column; Then Ctrl+S
		-- STEP 3 - Set relations (FKs) between tables, by right click on any column, and click 'Add' to add more; Then Ctrl+S
		
-- Using ALTER Queries
ALTER TABLE actor
ADD CONSTRAINT PK_actor_id PRIMARY KEY (actor_id);

ALTER TABLE category
ADD CONSTRAINT PK_category_id PRIMARY KEY (category_id);

ALTER TABLE film
ADD CONSTRAINT Pk_film_id PRIMARY KEY (film_id);

ALTER TABLE film_actor
ADD CONSTRAINT FK_actor_id FOREIGN KEY (actor_id) REFERENCES actor(actor_id);
ALTER TABLE film_actor
ADD CONSTRAINT FK_film_id FOREIGN KEY (film_id) REFERENCES film(film_id);

ALTER TABLE film_category
ADD CONSTRAINT FK_category_id FOREIGN KEY (category_id) REFERENCES category(category_id);
ALTER TABLE film_category
ADD CONSTRAINT FK_film_id FOREIGN KEY (film_id) REFERENCES film(film_id);

ALTER TABLE inventory
ADD CONSTRAINT PK_inventory_id PRIMARY KEY (inventory_id );
ALTER TABLE inventory
ADD CONSTRAINT FK_film_id FOREIGN KEY (film_id) REFERENCES film(film_id);

ALTER TABLE rental
ADD CONSTRAINT PK_rental_id PRIMARY KEY (rental_id);
ALTER TABLE rental
ADD CONSTRAINT FK_inventory_id FOREIGN KEY (inventory_id) REFERENCES inventory(inventory_id );



--TAST 2 : Determining cardinality/relationships within the data
--The number of unique inventory_id records will be equal in both rentals and inventory tables. Is this true?
SELECT COUNT(inventory_id) AS total_inventories,
COUNT(DISTINCT inventory_id) AS distinct_inventories
FROM rental;

SELECT COUNT(inventory_id) AS total_inventories,
COUNT(DISTINCT inventory_id) AS distinct_inventories
FROM inventory;

--There will be a multiple records per unique inventory_id in the rental table. Is this true?
SELECT inventory_id, COUNT(*) AS total_records
FROM rental
GROUP BY inventory_id
ORDER BY 2 DESC;

-- HENCE RELATION BETWEEN INVENTORY AND RENTAL IS ONE-TO-MANY

--There will be multiple inventory_id records per unique film_id value in the inventory table. Is this true?
SELECT film_id, COUNT(inventory_id) AS Total_inventories
FROM inventory
GROUP BY film_id;

--find out the relationship type between inventory and film tables. 
SELECT inventory_id, COUNT(film_id) AS Total_inventories
FROM inventory
GROUP BY inventory_id;

-- HENCE RELATION BETWEEN FILM AND INVENTORY IS ONE-TO-MANY



-- TASK 3 : What is the name of the most watched category in the category table?
SELECT TOP 1 C.name AS Category_name, COUNT(R.customer_id) AS Total_customers
FROM category AS C
JOIN film_category AS FC
ON C.category_id = FC.category_id
JOIN film  AS F
ON FC.film_id = F.film_id
JOIN inventory AS I
ON F.film_id = I.film_id
JOIN rental AS R
ON I.inventory_id = R.inventory_id
GROUP BY C.name
ORDER BY 2 DESC;



-- TASK 4 : Capture the rental level details along with most watched category.
SELECT R.*
FROM category AS C
JOIN film_category AS FC
ON C.category_id = FC.category_id
JOIN film  AS F
ON FC.film_id = F.film_id
JOIN inventory AS I
ON F.film_id = I.film_id
JOIN rental AS R
ON I.inventory_id = R.inventory_id
WHERE name in (SELECT name 
			 FROM
				(SELECT TOP 1 C.name, COUNT(R.customer_id) AS Total_customers
				FROM category AS C
				JOIN film_category AS FC
				ON C.category_id = FC.category_id
				JOIN film  AS F
				ON FC.film_id = F.film_id
				JOIN inventory AS I
				ON F.film_id = I.film_id
				JOIN rental AS R
				ON I.inventory_id = R.inventory_id
				GROUP BY C.name
				ORDER BY 2 DESC
) AS sq)



-- TASK 5 : Get the top 2 movies with max length in each category
SELECT name, title, length_rank
FROM
(
SELECT F.*, C.name,
ROW_NUMBER() OVER(PARTITION BY FC.category_id ORDER BY F.length DESC) AS length_rank
FROM film AS F
JOIN film_category AS FC
ON F.film_id = FC.film_id
JOIN category as C
ON FC.category_id = C. category_id) AS T
WHERE length_rank <= 2;



-- TASK 6 : For the films with the longest length, what is the title of the “R” rated film with the lowest replacement_cost in film table? [continuation from above]
WITH CTE1 AS
(
SELECT *
FROM
(
SELECT F.*, FC.category_id,
ROW_NUMBER() OVER(PARTITION BY FC.category_id ORDER BY F.length DESC) AS _rank
FROM film AS F
JOIN film_category AS FC
ON F.film_id = FC.film_id) AS T
WHERE _rank <= 2)

SELECT TOP 1 title, replacement_cost
FROM CTE1
WHERE _rank = 1 AND rating = 'R'
ORDER BY replacement_cost;



-- TASK 7: What is the frequency of values in the rating column in the film table? Identify the ratings with frequency > 200.
SELECT rating, COUNT(*) AS Total_films
FROM film
GROUP BY rating
HAVING COUNT(*) > 200;



-- TASK 8 : Top 3 viewed rating-type per customer so that store can make better recommendations
SELECT customer_id, rating, proportion
FROM(
	SELECT customer_id, rating, proportion,
			DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY proportion DESC) AS ranking
	FROM(
		SELECT customer_id, rating, CAST(watch_count*100.0/(total) AS decimal (10,2)) AS proportion
		FROM(
			SELECT *,
					SUM(watch_count) OVER(PARTITION BY customer_id) as total
			FROM (
				SELECT customer_id, rating, COUNT(rating) AS watch_count
				FROM rental AS r
				JOIN inventory AS i
				ON r.inventory_id = i.inventory_id
				JOIN film AS f
				ON f.film_id = i.film_id
				GROUP BY customer_id, rating
				) as sq1
			) as sq2
		) as sq3
	) AS sq4
WHERE ranking <= 3




-- TASK 9: Find the name of actor having most number of unique film_id records in the film_actor table?
SELECT TOP 1 CONCAT_WS(' ', first_name, last_name) AS Actor_name, 
COUNT(DISTINCT film_id) AS total_movies
FROM actor AS a
JOIN film_actor AS fa
ON a.actor_id = fa.actor_id
GROUP BY CONCAT_WS(' ', first_name, last_name)
ORDER BY 2 DESC;



-- TASK 10 : Most viewed actors per customer, for better recommendation
SELECT customer_id, actor
FROM(
	SELECT *, DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY rental_count DESC) as ranking
	FROM(
		SELECT customer_id, CONCAT_WS(' ', first_name, last_name) AS actor, count(*) rental_count
		FROM rental AS r
		JOIN inventory AS i ON r.inventory_id = i.inventory_id
		JOIN film AS f ON i.film_id = f.film_id
		JOIN film_actor AS fa on f.film_id = fa.film_id
		JOIN actor AS a ON fa.actor_id = a.actor_id
		GROUP BY customer_id, CONCAT_WS(' ', first_name, last_name)
		) as sq1
	) as sq2
WHERE ranking =1



-- TASK 11 : Top 10 viewed actors, so that store can manage inventory accordingly
SELECT TOP 10 actor, count(*) AS rentals
FROM(
	SELECT *, DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY rental_count DESC) as ranking
	FROM(
		SELECT customer_id, CONCAT_WS(' ', first_name, last_name) AS actor, count(*) rental_count
		FROM rental AS r
		JOIN inventory AS i ON r.inventory_id = i.inventory_id
		JOIN film AS f ON i.film_id = f.film_id
		JOIN film_actor AS fa on f.film_id = fa.film_id
		JOIN actor AS a ON fa.actor_id = a.actor_id
		GROUP BY customer_id, CONCAT_WS(' ', first_name, last_name)
		) as sq1
	) as sq2
WHERE ranking =1
GROUP BY actor
ORDER BY rentals DESC




-- TASK	12 : Divide the movies in 3 groups, long durations (>2.5 hrs), med duration (1.5 to 2.5 hrs) and short duration (<= 1.5 hrs) 
-- and check the total films and customers falling within individual category.
SELECT 
CASE 
WHEN 2.5 < (length / 60) THEN 'long duration'
WHEN (length / 60) BETWEEN 1.5 AND 2.5 THEN 'med duration'
ELSE 'short duration'
END AS duration_Category, 
COUNT(DISTINCT F.film_id) AS Total_movies,
COUNT(customer_id) AS Total_Customers
FROM film AS F
JOIN inventory AS I
ON F.film_id = I.film_id
JOIN rental AS R
ON I.inventory_id = R.inventory_id
GROUP BY CASE 
WHEN 2.5 < (length / 60) THEN 'long duration'
WHEN (length / 60) BETWEEN 1.5 AND 2.5 THEN 'med duration'
ELSE 'short duration'
END;




-- TASK 13 - Identify the films with special features of deleted or behind as a keyword present within them.
SELECT title, special_features
FROM film
WHERE special_features LIKE '%deleted%' OR  special_features LIKE '%behind%';



-- TASK 14 - What is percentage of rentals made in the Weekends vs. Weekdays?
SELECT '% of tickets in weekdays',COUNT(*)*100.0/(SELECT COUNT(*) FROM rental) AS [percentage]
FROM rental
WHERE DATENAME(dw, rental_date) NOT IN ('Saturday','Sunday')
UNION ALL
SELECT '% of tickets in weekends',COUNT(*)*100.0/(SELECT COUNT(*) FROM rental) AS [percentage]
FROM rental
WHERE DATENAME(dw, rental_date) IN ('Saturday','Sunday')



-- TASK 15 - How many rentals are being made at each hour
SELECT CONCAT(FORMAT([hour], '00'), ':00-', FORMAT([hour]+1, '00'), ':00') AS hour_range,
       total AS rentals
FROM 
	(
	SELECT DATEPART(HOUR, rental_date) AS [hour], COUNT(rental_date) AS total
	FROM rental
	GROUP BY DATEPART(HOUR, rental_date)
	) AS time_count
ORDER BY 2 DESC



-- TASK 16 - Check out how many customers are going to be penalized with the late fee. (if the return date - rental date > allowed duration
--of rental for a movie else replacement cost in case of no return date)
SELECT
CASE
WHEN return_date IS NULL THEN 'replacement fee'
WHEN DATEDIFF(DAY, rental_date, return_date) > rental_duration THEN 'late fee'
ELSE 'normal fee'
END AS fee_structure,
COUNT(customer_id) AS No_customers
FROM rental AS R
JOIN inventory AS I
ON R.inventory_id = I.inventory_id
JOIN film AS F
ON I.film_id = F.film_id
GROUP BY CASE
WHEN return_date IS NULL THEN 'replacement fee'
WHEN DATEDIFF(DAY, rental_date, return_date) > rental_duration THEN 'late fee'
ELSE 'normal fee'
END;



-- TASK 17 - Please calculate the total rental cost for a customer across the film they rented. Add an extra cost of late fee if
--it's more than the allowed rental duration. Add the replacement cost on top of it if customer hasn't returned the film.
SELECT customer_id, rental_id, fee_structure
FROM (SELECT R.*,
		CASE
		WHEN return_date IS NULL THEN (rental_duration * rental_rate) + replacement_cost
		WHEN DATEDIFF(DAY, rental_date, return_date) > rental_duration THEN DATEDIFF(DAY, rental_date, return_date) * (rental_rate + 0.49)
		ELSE rental_duration * rental_rate
		END AS fee_structure
		FROM rental AS R
		JOIN inventory AS I
		ON R.inventory_id = I.inventory_id
		JOIN film AS F
		ON I.film_id = F.film_id) AS sq


-- TASK 18 - Identify top 2 categories for each customer based off their past rental history.

SELECT *
FROM 
(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY Total_movies DESC) AS _rank
FROM
(
SELECT customer_id, C.name, COUNT(F.film_id) AS Total_Movies
FROM category AS C
JOIN film_category AS FC
ON C.category_id = FC.category_id
JOIN film  AS F
ON FC.film_id = F.film_id
JOIN inventory AS I
ON F.film_id = I.film_id
JOIN rental AS R
ON I.inventory_id = R.inventory_id
GROUP BY customer_id, C.name) AS T) AS T
WHERE _rank <= 2;



-- TASK 19 - For 1st category, identify average durations of films for each customer. 
WITH CTE2 AS
(
SELECT *
FROM 
(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY Total_movies DESC) AS _rank
FROM
(
SELECT customer_id, C.name, COUNT(F.film_id) AS Total_Movies
FROM category AS C
JOIN film_category AS FC
ON C.category_id = FC.category_id
JOIN film  AS F
ON FC.film_id = F.film_id
JOIN inventory AS I
ON F.film_id = I.film_id
JOIN rental AS R
ON I.inventory_id = R.inventory_id
GROUP BY customer_id, C.name) AS T) AS T
WHERE _rank <= 2)

SELECT CTE2.customer_id, C.name, AVG(length) AS avg_duration FROM CTE2 
JOIN rental AS R
ON CTE2.customer_id = R.customer_id
JOIN inventory AS I
ON R.inventory_id = I.inventory_id
JOIN film AS F
ON I.film_id = F.film_id
JOIN film_category AS FC
ON F.film_id = FC.film_id
JOIN category AS C
ON FC.category_id = C.category_id
WHERE _rank = 1 AND CTE2.customer_id = R.customer_id AND CTE2.name = C.name
GROUP BY CTE2.customer_id, C.name;


-- TASK 21 - For 2nd category, identify proportion of films watched in percentage within that category.
WITH CTE3 AS
(
SELECT *
FROM 
(
SELECT *,
ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY Total_movies DESC) AS _rank
FROM
(
SELECT customer_id, C.name AS Category_name, COUNT(F.film_id) AS Total_Movies
FROM category AS C
JOIN film_category AS FC
ON C.category_id = FC.category_id
JOIN film  AS F
ON FC.film_id = F.film_id
JOIN inventory AS I
ON F.film_id = I.film_id
JOIN rental AS R
ON I.inventory_id = R.inventory_id
GROUP BY customer_id, C.name) AS T) AS T
WHERE _rank <= 2)

SELECT CTE3.customer_id,CTE3.Category_name, CAST(CAST((CTE3.Total_Movies * 100.0/T.Total_movies) AS DECIMAL(18,2))  AS varchar(32)) + ' %' AS proportion
FROM CTE3
JOIN
(
SELECT C.name, COUNT(film_id) AS Total_movies
FROM category AS C
JOIN film_category AS FC
ON C.category_id = FC.category_id
GROUP BY C.name) AS T
ON CTE3.Category_name = T.name
WHERE _rank = 2;



-- TASK 22 - Store manager is interesed in understanding the growth/declining pattern of customers on monthly basis
SELECT *,
	CASE WHEN Previous_month_customers IS NOT NULL THEN Total_customers-Previous_month_customers END AS Customer_growth,
	CASE WHEN Previous_month_customers IS NOT NULL 
		 THEN CAST(CAST((Total_customers - Previous_month_customers) AS decimal (10,2)) /
					CAST(Previous_month_customers AS decimal (10,2))*100.0 
				AS DECIMAL (10,2)
				) END AS Growth_pct
FROM (SELECT *,
			LAG(Total_customers) OVER (ORDER BY Year, Month) AS Previous_month_customers    
		FROM (SELECT YEAR(rental_date) AS Year, MONTH(rental_date) AS Month, COUNT(customer_id) AS Total_customers
				FROM rental
				GROUP BY YEAR(rental_date), MONTH(rental_date)
				HAVING YEAR(rental_date) = '2005'  -- Another was '2006' which was of 'Feb' month, as there would be no continuity after Aug-2005
				) as sq
		) sq