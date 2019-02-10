DROP TABLE IF EXISTS export_data;

CREATE TEMP TABLE export_data AS
WITH nv AS (
  SELECT
    collision_unique_key,
    count(*) AS num_vehicles
  FROM collisions_vehicles
  GROUP BY collision_unique_key
)
SELECT
  extract(year FROM collision_time) AS year,
  CASE borough
    WHEN 'Bronx' THEN 'x'
    WHEN 'Brooklyn' THEN 'k'
    WHEN 'Manhattan' THEN 'm'
    WHEN 'Queens' THEN 'q'
    WHEN 'Staten Island' THEN 's'
  END AS borough,
  round(latitude, 5) AS lat,
  round(longitude, 5) AS lng,
  nv.num_vehicles,
  number_of_motorists_injured AS motorists_injured,
  number_of_motorists_killed AS motorists_killed,
  number_of_cyclists_injured AS cyclists_injured,
  number_of_cyclists_killed AS cyclists_killed,
  number_of_pedestrians_injured AS pedestrians_injured,
  number_of_pedestrians_killed AS pedestrians_killed,
  CASE
    WHEN extract(hour FROM collision_time) IN (8, 9, 10) THEN 'm'
    WHEN extract(hour FROM collision_time) IN (11, 12, 13, 14, 15) THEN 'i'
    WHEN extract(hour FROM collision_time) IN (16, 17, 18) THEN 'a'
    WHEN extract(hour FROM collision_time) IN (19, 20, 21) THEN 'e'
    ELSE 'o'
  END AS time_of_day
FROM collisions c
  LEFT JOIN nv ON c.unique_key = nv.collision_unique_key
WHERE latitude IS NOT NULL
  AND longitude IS NOT NULL
  AND latitude BETWEEN 40.4 AND 41
  AND longitude BETWEEN -74.4 AND -73.5
ORDER BY unique_key;

\copy (SELECT * FROM export_data) TO 'nyc_motor_vehicle_collisions.csv' CSV HEADER;
