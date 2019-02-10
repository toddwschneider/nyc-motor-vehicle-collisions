SET datestyle = 'ISO, MDY';

\copy collisions_raw FROM 'raw_data/collisions.csv' CSV HEADER;

CREATE TABLE tmp_points AS
SELECT
  unique_key,
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326) AS location
FROM collisions_raw
WHERE longitude IS NOT NULL AND latitude IS NOT NULL;

CREATE INDEX ON tmp_points USING gist (location);

CREATE TABLE tmp_zones AS
SELECT t.unique_key, z.gid, z.borough
FROM tmp_points t, taxi_zones z
WHERE ST_Within(t.location, z.geom);

CREATE UNIQUE INDEX ON tmp_zones (unique_key);

CREATE TABLE tmp_tracts AS
SELECT t.unique_key, n.gid, n.boroname
FROM tmp_points t, nyct2010 n
WHERE ST_Within(t.location, n.geom);

CREATE UNIQUE INDEX ON tmp_tracts (unique_key);

DELETE FROM collisions
WHERE unique_key IN (SELECT unique_key FROM collisions_raw);

INSERT INTO collisions (
  unique_key, collision_time, taxi_zone_gid, nyct2010_gid, borough,
  reported_borough, zip_code, latitude, longitude, on_street_name,
  cross_street_name, off_street_name, number_of_persons_injured,
  number_of_persons_killed, number_of_pedestrians_injured,
  number_of_pedestrians_killed, number_of_cyclists_injured,
  number_of_cyclists_killed, number_of_motorists_injured,
  number_of_motorists_killed, contributing_factor_vehicle_1,
  contributing_factor_vehicle_2, contributing_factor_vehicle_3,
  contributing_factor_vehicle_4, contributing_factor_vehicle_5,
  vehicle_type_code_1, vehicle_type_code_2, vehicle_type_code_3,
  vehicle_type_code_4, vehicle_type_code_5, coordinates_source
)
SELECT
  r.unique_key,
  (r.date || ' ' || r.time)::timestamp without time zone AS collision_time,
  z.gid AS taxi_zone_gid,
  t.gid AS nyct2010_gid,
  -- prefer borough from nyct2010 over taxi_zones because nyct2010
  -- includes water areas and therefore captures bridge accidents
  coalesce(t.boroname, z.borough) AS borough,
  nullif(lower(trim(r.borough)), '') AS reported_borough,
  nullif(trim(r.zip_code), '') AS zip_code,
  nullif(r.latitude, 0) AS latitude,
  nullif(r.longitude, 0) AS longitude,
  nullif(lower(trim(regexp_replace(r.on_street_name, '\s+', ' ', 'g'))), '') AS on_street_name,
  nullif(lower(trim(regexp_replace(r.cross_street_name, '\s+', ' ', 'g'))), '') AS cross_street_name,
  nullif(lower(trim(regexp_replace(r.off_street_name, '\s+', ' ', 'g'))), '') AS off_street_name,
  r.number_of_persons_injured,
  r.number_of_persons_killed,
  r.number_of_pedestrians_injured,
  r.number_of_pedestrians_killed,
  r.number_of_cyclists_injured,
  r.number_of_cyclists_killed,
  r.number_of_motorists_injured,
  r.number_of_motorists_killed,
  nullif(lower(trim(r.contributing_factor_vehicle_1)), '') AS contributing_factor_vehicle_1,
  nullif(lower(trim(r.contributing_factor_vehicle_2)), '') AS contributing_factor_vehicle_2,
  nullif(lower(trim(r.contributing_factor_vehicle_3)), '') AS contributing_factor_vehicle_3,
  nullif(lower(trim(r.contributing_factor_vehicle_4)), '') AS contributing_factor_vehicle_4,
  nullif(lower(trim(r.contributing_factor_vehicle_5)), '') AS contributing_factor_vehicle_5,
  nullif(lower(trim(r.vehicle_type_code_1)), '') AS vehicle_type_code_1,
  nullif(lower(trim(r.vehicle_type_code_2)), '') AS vehicle_type_code_2,
  nullif(lower(trim(r.vehicle_type_code_3)), '') AS vehicle_type_code_3,
  nullif(lower(trim(r.vehicle_type_code_4)), '') AS vehicle_type_code_4,
  nullif(lower(trim(r.vehicle_type_code_5)), '') AS vehicle_type_code_5,
  CASE
    WHEN nullif(r.latitude, 0) IS NOT NULL AND nullif(r.longitude, 0) IS NOT NULL
    THEN 'raw_data'
  END AS coordinates_source
FROM collisions_raw r
  LEFT JOIN tmp_zones z ON r.unique_key = z.unique_key
  LEFT JOIN tmp_tracts t ON r.unique_key = t.unique_key
ORDER BY r.date, r.time;

TRUNCATE TABLE collisions_raw;
DROP TABLE tmp_points;
DROP TABLE tmp_zones;
DROP TABLE tmp_tracts;
