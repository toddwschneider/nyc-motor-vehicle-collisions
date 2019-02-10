source("helpers.R")
library(glmnet)

# set up regression data
regression_collisions = query("
  SELECT
    unique_key,
    extract(hour FROM collision_time) AS hour_of_day,
    extract(dow FROM collision_time) AS day_of_week,
    extract(year FROM collision_time) AS year,
    coalesce(on_street_name, off_street_name) AS street_name,
    borough,
    number_of_motorists_injured + number_of_cyclists_injured + number_of_pedestrians_injured > 0 AS has_injury,
    number_of_motorists_killed + number_of_cyclists_killed + number_of_pedestrians_killed > 0 AS has_fatality
  FROM collisions
  WHERE borough IS NOT NULL
  ORDER BY unique_key
")

regression_contributing_factors = query("
  WITH candidates AS (
    SELECT contributing_factor
    FROM collisions_contributing_factors
    GROUP BY contributing_factor
    HAVING COUNT(*) >= 5000
  )
  SELECT *
  FROM collisions_contributing_factors
  WHERE contributing_factor IN (SELECT contributing_factor FROM candidates)
")

regression_vehicle_types = query("
  WITH candidates AS (
    SELECT vehicle_type
    FROM collisions_vehicles
    GROUP BY vehicle_type
    HAVING COUNT(*) >= 5000
  )
  SELECT *
  FROM collisions_vehicles
  WHERE vehicle_type IN (SELECT vehicle_type FROM candidates)
")

regression_vehicles_involved = query("
  SELECT collision_unique_key, count(*)::int AS num_vehicles
  FROM collisions_vehicles
  GROUP BY collision_unique_key
  ORDER BY collision_unique_key
")

regression_collisions = regression_collisions %>%
  inner_join(regression_vehicles_involved, by = c("unique_key" = "collision_unique_key")) %>%
  mutate(
    hour_of_day = factor(hour_of_day, levels = c(12:23, 0:11)),
    day_of_week = factor(day_of_week),
    weekday = factor(day_of_week %in% 1:5),
    year = factor(year),
    borough = fct_relevel(factor(borough), "Manhattan"),
    num_vehicles = factor(num_vehicles, levels = c(2, 1, 3, 4, 5)),
    street_type = fct_relevel(factor(case_when(
      grepl("expressway|expy|expwy|parkway|pkwy|highway|bqe|turnpike|fdr|thruway", street_name) ~ "highway",
      grepl("street| st$", street_name) ~ "street",
      grepl("avenue|broadway|bowery| ave$", street_name) ~ "avenue",
      grepl(" road| rd$", street_name) ~ "road",
      grepl(" lane| ln$", street_name) ~ "lane",
      grepl(" drive| dr$", street_name) ~ "drive",
      grepl("boulevard|blvd", street_name) ~ "boulevard",
      grepl(" place| pl$", street_name) ~ "place",
      grepl("bridge", street_name) ~ "bridge",
      grepl("tunnel", street_name) ~ "tunnel",
      !is.na(street_name) ~ "other",
      TRUE ~ "unknown"
    )), "unknown")
  )

for(f in sort(unique(regression_contributing_factors$contributing_factor))) {
  fname = paste0("cf_", gsub(".", "_", make.names(f), fixed = TRUE))

  factor_unique_keys = regression_contributing_factors %>%
    filter(contributing_factor == f) %>%
    pull(collision_unique_key) %>%
    unique()

  regression_collisions = regression_collisions %>%
    mutate(!!fname := as.numeric(unique_key %in% factor_unique_keys))
}

for(v in sort(unique(regression_vehicle_types$vehicle_type))) {
  vname = paste0("vt_", gsub(".", "_", make.names(v), fixed = TRUE))

  vehicle_unique_keys = regression_vehicle_types %>%
    filter(vehicle_type == v) %>%
    pull(collision_unique_key) %>%
    unique()

  regression_collisions = regression_collisions %>%
    mutate(!!vname := as.numeric(unique_key %in% vehicle_unique_keys))
}

# build model matrices
injury_model_matrix = sparse.model.matrix(
  has_injury ~ . - 1,
  select(regression_collisions, -day_of_week, -street_name, -unique_key, -has_fatality)
)

fatality_model_matrix = sparse.model.matrix(
  has_fatality ~ . - 1,
  select(regression_collisions, -day_of_week, -street_name, -unique_key, -has_injury)
)

# run regularized regressions
injury_cvfit = cv.glmnet(
  x = injury_model_matrix,
  y = regression_collisions$has_injury,
  family = "binomial"
)

fatality_cvfit = cv.glmnet(
  x = fatality_model_matrix,
  y = regression_collisions$has_fatality,
  family = "binomial"
)

# check on lambda values and coefficients
plot(injury_cvfit)
coef(injury_cvfit, s = "lambda.1se")

plot(fatality_cvfit)
coef(fatality_cvfit, s = "lambda.1se")
