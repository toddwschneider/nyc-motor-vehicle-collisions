#!/bin/bash

createdb nyc-motor-vehicle-collisions

psql nyc-motor-vehicle-collisions -f setup_files/create_schema.sql

shp2pgsql -I -s 2263:4326 shapefiles/taxi_zones/taxi_zones.shp | psql -d nyc-motor-vehicle-collisions
psql nyc-motor-vehicle-collisions -c "CREATE INDEX ON taxi_zones (locationid);"
psql nyc-motor-vehicle-collisions -c "VACUUM ANALYZE taxi_zones;"

shp2pgsql -I -s 2263:4326 shapefiles/nyct2010wi_18d/nyct2010wi.shp nyct2010 | psql -d nyc-motor-vehicle-collisions
psql nyc-motor-vehicle-collisions -c "VACUUM ANALYZE nyct2010;"
