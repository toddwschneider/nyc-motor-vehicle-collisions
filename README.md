# NYC Motor Vehicle Collisions

Code in support of this post: [Mapping Motor Vehicle Collisions in New York City](http://toddwschneider.com/posts/nyc-motor-vehicle-collisions-map/)

Raw data comes from the NYPD: https://data.cityofnewyork.us/Public-Safety/NYPD-Motor-Vehicle-Collisions/h9gi-nx95

## Instructions

1. Download and install PostgreSQL and PostGIS (both are available via Homebrew)
2. `./download_raw_data.sh`
3. `./initialize_database.sh`
4. `./import_data.sh`

Additional code to fill in missing coordinates for collisions that have cross streets or addresses but no lat/lon lives in the `augment_data/` subfolder

Assorted SQL and R scripts to analyze data and draw maps are in the `analysis/` subfolder
