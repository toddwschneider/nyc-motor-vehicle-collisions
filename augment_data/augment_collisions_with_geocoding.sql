CREATE TABLE tmp_points AS
SELECT
  id,
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326) AS location
FROM geocodings
WHERE (taxi_zone_gid IS NULL OR nyct2010_gid IS NULL)
  AND latitude IS NOT NULL
  AND longitude IS NOT NULL;

CREATE INDEX ON tmp_points USING gist (location);

CREATE TABLE tmp_zones AS
SELECT t.id, z.gid, z.borough
FROM tmp_points t, taxi_zones z
WHERE ST_Within(t.location, z.geom);

CREATE UNIQUE INDEX ON tmp_zones (id);

CREATE TABLE tmp_tracts AS
SELECT t.id, n.gid, n.boroname
FROM tmp_points t, nyct2010 n
WHERE ST_Within(t.location, n.geom);

CREATE UNIQUE INDEX ON tmp_tracts (id);

UPDATE geocodings
SET taxi_zone_gid = tmp_zones.gid,
    borough = tmp_zones.borough
FROM tmp_zones
WHERE geocodings.id = tmp_zones.id;

UPDATE geocodings
SET nyct2010_gid = tmp_tracts.gid,
    borough = tmp_tracts.boroname
FROM tmp_tracts
WHERE geocodings.id = tmp_tracts.id;

WITH coords AS (
  SELECT
    c.unique_key,
    g.latitude,
    g.longitude,
    g.taxi_zone_gid,
    g.borough,
    g.nyct2010_gid
  FROM collisions c
    INNER JOIN geocodings g
      ON coalesce(c.on_street_name, '') = coalesce(g.on_street_name, '')
      AND coalesce(c.cross_street_name, '') = coalesce(g.cross_street_name, '')
      AND coalesce(c.off_street_name, '') = coalesce(g.off_street_name, '')
      AND coalesce(c.reported_borough, '') = coalesce(g.reported_borough, '')
  WHERE c.latitude IS NULL
    AND c.longitude IS NULL
    AND g.latitude IS NOT NULL
    AND g.longitude IS NOT NULL
)
UPDATE collisions
SET latitude = coords.latitude,
    longitude = coords.longitude,
    taxi_zone_gid = coords.taxi_zone_gid,
    borough = coords.borough,
    nyct2010_gid = coords.nyct2010_gid,
    coordinates_source = 'geocoding'
FROM coords
WHERE collisions.unique_key = coords.unique_key;

DROP TABLE tmp_points;
DROP TABLE tmp_zones;
DROP TABLE tmp_tracts;
