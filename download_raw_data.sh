#!/bin/bash

echo "`date`: downloading raw data"
mkdir -p raw_data
wget -c -O raw_data/collisions.csv https://data.cityofnewyork.us/api/views/h9gi-nx95/rows.csv?accessType=DOWNLOAD
echo "`date`: done downloading raw data"
