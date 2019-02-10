CREATE TEMP TABLE most_common_coords AS
WITH candidates AS (
  SELECT
    on_street_name,
    cross_street_name,
    borough,
    taxi_zone_gid,
    nyct2010_gid,
    round(latitude, 4) AS lat,
    round(longitude, 4) AS lng,
    count(*) AS n
  FROM collisions
  WHERE coordinates_source = 'raw_data'
    AND latitude IS NOT NULL
    AND longitude IS NOT NULL
    AND on_street_name IS NOT NULL
    AND (
      cross_street_name IS NOT NULL
      OR on_street_name LIKE '% bridge'
    )
  GROUP BY on_street_name, cross_street_name, borough, taxi_zone_gid, nyct2010_gid, lat, lng
)
SELECT DISTINCT ON (on_street_name, cross_street_name) *
FROM candidates
WHERE n >= 2
ORDER BY on_street_name, cross_street_name, n DESC;

WITH most_common AS (
  SELECT
    c.unique_key,
    mcc.lat,
    mcc.lng,
    mcc.taxi_zone_gid,
    mcc.borough,
    mcc.nyct2010_gid
  FROM collisions c
    INNER JOIN most_common_coords mcc
      ON c.on_street_name IS NOT NULL
      AND c.on_street_name = mcc.on_street_name
      AND coalesce(c.cross_street_name, '') = coalesce(mcc.cross_street_name, '')
  WHERE c.latitude IS NULL
    AND c.longitude IS NULL
)
UPDATE collisions
SET latitude = most_common.lat,
    longitude = most_common.lng,
    taxi_zone_gid = most_common.taxi_zone_gid,
    borough = most_common.borough,
    nyct2010_gid = most_common.nyct2010_gid,
    coordinates_source = 'most_common_in_raw_data'
FROM most_common
WHERE collisions.unique_key = most_common.unique_key;

DROP TABLE most_common_coords;
