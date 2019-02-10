#!/bin/bash

echo "`date`: importing raw data"
psql nyc-motor-vehicle-collisions -f setup_files/import_data.sql
echo "`date`: done importing raw data; populating vehicles and contributing factors"
psql nyc-motor-vehicle-collisions -f setup_files/populate_vehicles_and_factors.sql
echo "`date`: done populating; creating indexes"
psql nyc-motor-vehicle-collisions -f setup_files/create_indexes.sql
echo "`date`: done"
