# Fill in collision records that are missing coordinates

~13% of the collisions in the raw dataset are missing lat/lon coordinates. Many of those records have cross streets or addresses, which can be used to fill in coordinates with reasonable guesses. There are 2 strategies used to fill in missing coordinates: other collisions at the same cross streets, and geocoding. These processes add coordinates for ~8% of the full dataset, leaving ~5% of collisions without coordinates. The `collisions.coordinates_source` column keeps track of where each collision's coordinates came from. It's possible these augmentation processes might introduce some data errors, but an anecdotal manual review suggested that they are accurate more often than not.

## Coordinates from other collisions listed at the same cross streets

Calculate the most common coordinates for each pair of cross streets, and use them to fill in coordinates for collisions at the same cross streets that are missing coordinates. E.g. there are collisions listed at Bruckner Boulevard & E 138 St that are missing coordinates, but there are also collisions at the same cross streets that have coordinates, so assume that the unknown Bruckner & E 138 collisions happened at the most common coordinates listed for the known Bruckner & E 138 collisions, subject there being at least 2 known collisions at the same lat/lon rounded to 4 digits.

`psql nyc-motor-vehicle-collisions -f augment_collisions_with_most_common_coordinates.sql`

## Geocode missing coordinates

1. Get a Google Maps Geocoding API key: https://developers.google.com/maps/documentation/geocoding/get-api-key
2. `psql nyc-motor-vehicle-collisions -f populate_geocodings.sql`
3. `bundle install`
4. `ruby geocode.rb --google-api-key YOUR_API_KEY_HERE`
5. `psql nyc-motor-vehicle-collisions -f augment_collisions_with_geocoding.sql`

Note that as of January 2019, Google Maps Geocoding API allows up to 40,000 requests per month for free in the United States, then charges $5 per 1,000 requests after that. See https://developers.google.com/maps/documentation/geocoding/usage-and-billing for the latest pricing. When I ran `geocode.rb` there fewer than 40,000 records to geocode, so I was able to do it for free.

## Augmentation results

Coordinates sources with raw data through 12/31/2018:

```sql
SELECT
  extract(year FROM collision_time) AS year,
  COUNT(*) AS n,
  ROUND(SUM(CASE WHEN coordinates_source = 'raw_data' THEN 1 END)::numeric / COUNT(*), 2) AS raw_data,
  ROUND(SUM(CASE WHEN coordinates_source = 'most_common_in_raw_data' THEN 1 END)::numeric / COUNT(*), 2) AS most_common_in_raw_data,
  ROUND(SUM(CASE WHEN coordinates_source = 'geocoding' THEN 1 END)::numeric / COUNT(*), 2) AS geocoding,
  ROUND(SUM(CASE WHEN coordinates_source IS NULL THEN 1 END)::numeric / COUNT(*), 2) AS unknown
FROM collisions
GROUP BY year
ORDER BY year;
```

```sql
 year |   n    | raw_data | most_common_in_raw_data | geocoding | unknown
------+--------+----------+-------------------------+-----------+---------
 2012 | 100541 |     0.85 |                    0.06 |      0.03 |    0.06
 2013 | 203727 |     0.84 |                    0.07 |      0.03 |    0.06
 2014 | 206028 |     0.84 |                    0.07 |      0.03 |    0.06
 2015 | 217693 |     0.84 |                    0.07 |      0.03 |    0.06
 2016 | 229780 |     0.84 |                    0.08 |      0.03 |    0.05
 2017 | 230991 |     0.94 |                    0.01 |      0.03 |    0.02
 2018 | 231016 |     0.93 |                    0.01 |      0.03 |    0.03
```
