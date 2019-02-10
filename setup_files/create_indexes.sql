CREATE INDEX ON collisions (taxi_zone_gid);
CREATE INDEX ON collisions (borough);
CREATE INDEX ON collisions USING brin (collision_time) WITH (pages_per_range = 32);
