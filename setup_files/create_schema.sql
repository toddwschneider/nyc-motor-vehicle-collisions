CREATE EXTENSION postgis;

CREATE TABLE collisions_raw (
  date date,
  time time,
  borough text,
  zip_code text,
  latitude numeric,
  longitude numeric,
  location text,
  on_street_name text,
  cross_street_name text,
  off_street_name text,
  number_of_persons_injured integer,
  number_of_persons_killed integer,
  number_of_pedestrians_injured integer,
  number_of_pedestrians_killed integer,
  number_of_cyclists_injured integer,
  number_of_cyclists_killed integer,
  number_of_motorists_injured integer,
  number_of_motorists_killed integer,
  contributing_factor_vehicle_1 text,
  contributing_factor_vehicle_2 text,
  contributing_factor_vehicle_3 text,
  contributing_factor_vehicle_4 text,
  contributing_factor_vehicle_5 text,
  unique_key integer primary key,
  vehicle_type_code_1 text,
  vehicle_type_code_2 text,
  vehicle_type_code_3 text,
  vehicle_type_code_4 text,
  vehicle_type_code_5 text
);

CREATE TABLE collisions (
  unique_key integer primary key,
  collision_time timestamp without time zone,
  taxi_zone_gid integer,
  nyct2010_gid integer,
  borough text,
  reported_borough text,
  zip_code text,
  latitude numeric,
  longitude numeric,
  on_street_name text,
  cross_street_name text,
  off_street_name text,
  number_of_persons_injured integer,
  number_of_persons_killed integer,
  number_of_pedestrians_injured integer,
  number_of_pedestrians_killed integer,
  number_of_cyclists_injured integer,
  number_of_cyclists_killed integer,
  number_of_motorists_injured integer,
  number_of_motorists_killed integer,
  contributing_factor_vehicle_1 text,
  contributing_factor_vehicle_2 text,
  contributing_factor_vehicle_3 text,
  contributing_factor_vehicle_4 text,
  contributing_factor_vehicle_5 text,
  vehicle_type_code_1 text,
  vehicle_type_code_2 text,
  vehicle_type_code_3 text,
  vehicle_type_code_4 text,
  vehicle_type_code_5 text,
  coordinates_source text
);

CREATE TABLE collisions_vehicles (
  collision_unique_key integer not null,
  vehicle_number integer not null,
  vehicle_type text,
  primary key (collision_unique_key, vehicle_number)
);

CREATE TABLE collisions_contributing_factors (
  collision_unique_key integer not null,
  contributing_number integer not null,
  contributing_factor text,
  primary key (collision_unique_key, contributing_number)
);

CREATE TABLE geocodings (
  id serial primary key,
  type text not null,
  on_street_name text,
  cross_street_name text,
  off_street_name text,
  reported_borough text,
  n integer,
  latitude numeric,
  longitude numeric,
  full_response jsonb,
  taxi_zone_gid integer,
  nyct2010_gid integer,
  borough text
);

CREATE UNIQUE INDEX ON geocodings (on_street_name, cross_street_name, reported_borough) WHERE off_street_name IS NULL;
CREATE UNIQUE INDEX ON geocodings (on_street_name, cross_street_name) WHERE off_street_name IS NULL AND reported_borough IS NULL;
CREATE UNIQUE INDEX ON geocodings (off_street_name, reported_borough) WHERE on_street_name IS NULL;
CREATE UNIQUE INDEX ON geocodings (off_street_name) WHERE on_street_name IS NULL AND reported_borough IS NULL;
