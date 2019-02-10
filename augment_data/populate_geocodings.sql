INSERT INTO geocodings (type, on_street_name, cross_street_name, reported_borough, n)
SELECT
  'IntersectionGeocoding'::text AS type,
  on_street_name,
  cross_street_name,
  reported_borough,
  COUNT(*) AS n
FROM collisions
WHERE latitude IS NULL
  AND longitude IS NULL
  AND on_street_name IS NOT NULL
  AND cross_street_name IS NOT NULL
GROUP BY on_street_name, cross_street_name, reported_borough
ORDER BY COUNT(*) DESC, on_street_name, cross_street_name, reported_borough;

INSERT INTO geocodings (type, off_street_name, reported_borough, n)
SELECT
  'StreetAddressGeocoding'::text AS type,
  off_street_name,
  reported_borough,
  COUNT(*) AS n
FROM collisions
WHERE latitude IS NULL
  AND longitude IS NULL
  AND off_street_name IS NOT NULL
GROUP BY off_street_name, reported_borough
ORDER BY COUNT(*) DESC, off_street_name, reported_borough;
