INSERT INTO collisions_vehicles
  (collision_unique_key, vehicle_number, vehicle_type)
WITH vehicles AS (
  SELECT
    unique_key,
    ARRAY[1, 2, 3, 4, 5] AS vehicle_number_array,
    ARRAY[
      vehicle_type_code_1,
      vehicle_type_code_2,
      vehicle_type_code_3,
      vehicle_type_code_4,
      vehicle_type_code_5
    ] AS vehicle_type_array
  FROM collisions
),
unnested AS (
  SELECT
    unique_key,
    unnest(vehicle_number_array) AS vehicle_number,
    unnest(vehicle_type_array) AS vehicle_type
  FROM vehicles
)
SELECT unique_key, vehicle_number, vehicle_type
FROM unnested
WHERE vehicle_type IS NOT NULL
ORDER BY unique_key, vehicle_number
ON CONFLICT (collision_unique_key, vehicle_number)
DO UPDATE SET vehicle_type = EXCLUDED.vehicle_type;

INSERT INTO collisions_contributing_factors
  (collision_unique_key, contributing_number, contributing_factor)
WITH vehicles AS (
  SELECT
    unique_key,
    ARRAY[1, 2, 3, 4, 5] AS contributing_number_array,
    ARRAY[
      contributing_factor_vehicle_1,
      contributing_factor_vehicle_2,
      contributing_factor_vehicle_3,
      contributing_factor_vehicle_4,
      contributing_factor_vehicle_5
    ] AS contributing_factor_array
  FROM collisions
),
unnested AS (
  SELECT
    unique_key,
    unnest(contributing_number_array) AS contributing_number,
    unnest(contributing_factor_array) AS contributing_factor
  FROM vehicles
)
SELECT unique_key, contributing_number, contributing_factor
FROM unnested
WHERE contributing_factor IS NOT NULL
ORDER BY unique_key, contributing_number
ON CONFLICT (collision_unique_key, contributing_number)
DO UPDATE SET contributing_factor = EXCLUDED.contributing_factor;
