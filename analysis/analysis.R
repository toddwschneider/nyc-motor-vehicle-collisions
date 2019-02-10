source("helpers.R")

collisions = query("
  SELECT
    unique_key,
    collision_time::date AS date,
    date(date_trunc('month', collision_time)) AS month,
    extract(hour FROM collision_time) AS hour_of_day,
    extract(dow FROM collision_time) AS day_of_week,
    latitude,
    longitude,
    z.locationid,
    z.zone,
    c.borough,
    nyct2010_gid,
    number_of_motorists_injured + number_of_cyclists_injured + number_of_pedestrians_injured AS people_injured,
    number_of_motorists_injured AS motorists_injured,
    number_of_cyclists_injured AS cyclists_injured,
    number_of_pedestrians_injured AS pedestrians_injured,
    number_of_motorists_killed + number_of_cyclists_killed + number_of_pedestrians_killed AS people_killed,
    number_of_motorists_killed AS motorists_killed,
    number_of_cyclists_killed AS cyclists_killed,
    number_of_pedestrians_killed AS pedestrians_killed
  FROM collisions c
    LEFT JOIN taxi_zones z ON c.taxi_zone_gid = z.gid
  ORDER BY unique_key
")

zb = query("SELECT DISTINCT zone, borough FROM taxi_zones ORDER BY zone")

date_seq = seq(
  min(collisions$date),
  max(collisions$date),
  by = "1 day"
)

variable_factor_levels = c(
  "collisions",
  "people_injured",
  "people_killed",
  "motorists_injured",
  "motorists_killed",
  "cyclists_injured",
  "cyclists_killed",
  "pedestrians_injured",
  "pedestrians_killed"
)

variable_factor_labels = variable_factor_levels %>%
  gsub("_", " ", .) %>%
  capitalize_first_letter()

aggregate_collisions = function(dimensions = quos()) {
  dimensions_excluded = purrr::map(dimensions, function(d) expr(-!!d))

  collisions %>%
    mutate(collisions = 1) %>%
    select(!!!dimensions, date, collisions, matches("_(injured|killed)$")) %>%
    group_by(!!!dimensions, date) %>%
    summarize_all(sum) %>%
    ungroup() %>%
    group_by(!!!dimensions) %>%
    complete(
      date = date_seq,
      fill = list(
        collisions = 0,
        people_injured = 0,
        motorists_injured = 0,
        cyclists_injured = 0,
        pedestrians_injured = 0,
        people_killed = 0,
        motorists_killed = 0,
        cyclists_killed = 0,
        pedestrians_killed = 0
      )
    ) %>%
    ungroup() %>%
    gather(variable, daily, -date, !!!dimensions_excluded) %>%
    group_by(!!!dimensions, variable) %>%
    arrange(!!!dimensions, variable, date) %>%
    mutate(
      rolling28 = rollsumr(daily, k = 28, na.pad = TRUE),
      rolling365 = rollsumr(daily, k = 365, na.pad = TRUE)
    ) %>%
    ungroup() %>%
    mutate(
      year = year(date),
      variable = factor(variable, levels = variable_factor_levels, labels = variable_factor_labels)
    )
}

aggregate_collisions_by_year = function(dimensions = quos()) {
  aggregate_collisions(dimensions = dimensions) %>%
    group_by(!!!dimensions, variable, year) %>%
    summarize(total = sum(daily)) %>%
    ungroup()
}

aggregated_data = aggregate_collisions_by_year() %>%
  filter(year %in% 2013:2018)

aggregated_data_by_borough = aggregate_collisions_by_year(dimensions = quos(borough)) %>%
  filter(year %in% 2013:2018)

aggregated_data_by_zone = aggregate_collisions_by_year(dimensions = quos(zone)) %>%
  filter(year %in% 2013:2018) %>%
  inner_join(zb, by = "zone")

zones = aggregated_data_by_zone %>%
  distinct(zone) %>%
  filter(!is.na(zone)) %>%
  pull(zone)

plot_bs = 32
plot_width = 800

p1 = aggregated_data %>%
  filter(variable == "Collisions") %>%
  ggplot(aes(x = year, y = total)) +
  geom_line(size = 1, color = nypd_blue) +
  geom_point(size = 3, color = nypd_blue) +
  geom_blank(aes(y = 0)) +
  geom_blank(aes(y = 1.3 * total)) +
  scale_y_continuous(labels = scales::comma) +
  ggtitle("New York City Motor Vehicle Collisions", "Annual total") +
  labs(caption = "Data via NYPD\ntoddwschneider.com") +
  theme_tws(base_size = plot_bs) +
  theme(
    axis.title = element_blank(),
    panel.grid.minor.x = element_blank()
  )

p2 = aggregated_data %>%
  filter(variable != "Collisions") %>%
  ggplot(aes(x = year, y = total)) +
  geom_line(size = 1, color = nypd_blue) +
  geom_point(size = 3, color = nypd_blue) +
  geom_blank(aes(y = 0)) +
  geom_blank(aes(y = 1.4 * total)) +
  scale_x_continuous(breaks = c(2014, 2016, 2018)) +
  scale_y_continuous(labels = scales::comma) +
  facet_wrap(~variable, scales = "free_y", ncol = 2) +
  ggtitle("New York City", "Annual injuries from motor vehicle collisions") +
  labs(caption = "Data via NYPD\ntoddwschneider.com") +
  theme_tws(base_size = plot_bs) +
  theme(
    axis.title = element_blank(),
    panel.grid.minor.y = element_blank(),
    plot.subtitle = element_text(margin = unit(c(0, 0, 1.1, 0), "lines")),
    plot.margin = margin(plot_bs / 2, plot_bs * 0.75, plot_bs / 2, plot_bs / 2),
    axis.text = element_text(size = rel(0.7)),
    strip.text = element_text(size = rel(0.7))
  )

png("graphs/nyc_collisions.png", height = plot_width * 0.75, width = plot_width)
print(p1)
dev.off()

png("graphs/nyc_injuries.png", height = plot_width * 1.5, width = plot_width)
print(p2)
dev.off()

for (b in c("Bronx", "Brooklyn", "Manhattan", "Queens", "Staten Island")) {
  p1 = aggregated_data_by_borough %>%
    filter(borough == b, variable == "Collisions") %>%
    ggplot(aes(x = year, y = total)) +
    geom_line(size = 1, color = nypd_blue) +
    geom_point(size = 3, color = nypd_blue) +
    geom_blank(aes(y = 0)) +
    geom_blank(aes(y = 1.4 * total)) +
    scale_x_continuous(breaks = c(2014, 2016, 2018)) +
    scale_y_continuous(labels = scales::comma) +
    ggtitle(paste(b, "Motor Vehicle Collisions"), "Annual total") +
    labs(caption = "Data via NYPD\ntoddwschneider.com") +
    theme_tws(base_size = plot_bs) +
    theme(
      axis.title = element_blank(),
      panel.grid.minor.y = element_blank()
    )

  p2 = aggregated_data_by_borough %>%
    filter(variable != "Collisions", borough == b) %>%
    ggplot(aes(x = year, y = total)) +
    geom_line(size = 1, color = nypd_blue) +
    geom_point(size = 3, color = nypd_blue) +
    geom_blank(aes(y = 0)) +
    geom_blank(aes(y = 1.4 * total)) +
    scale_x_continuous(breaks = c(2014, 2016, 2018)) +
    scale_y_continuous(labels = scales::comma, breaks = integer_breaks(n = 3)) +
    facet_wrap(~variable, scales = "free_y", ncol = 2) +
    ggtitle(b, "Annual injuries from motor vehicle collisions") +
    labs(caption = "Data via NYPD\ntoddwschneider.com") +
    theme_tws(base_size = plot_bs) +
    theme(
      axis.title = element_blank(),
      panel.grid.minor.y = element_blank(),
      plot.subtitle = element_text(margin = unit(c(0, 0, 1.1, 0), "lines")),
      plot.margin = margin(plot_bs / 2, plot_bs * 0.75, plot_bs / 2, plot_bs / 2),
      axis.text = element_text(size = rel(0.7)),
      strip.text = element_text(size = rel(0.7))
    )

  png(paste0("graphs/boroughs/", tolower(gsub(" ", "_", b)), "_collisions.png"), height = plot_width * 0.75, width = plot_width)
  print(p1)
  dev.off()

  png(paste0("graphs/boroughs/", tolower(gsub(" ", "_", b)), "_injuries.png"), height = plot_width * 1.5, width = plot_width)
  print(p2)
  dev.off()
}

for (z in zones) {
  zfile = z %>%
    str_replace_all("['()]", "") %>%
    str_replace_all("[\\s/]", "_") %>%
    tolower()

  borough = filter(zb, zone == z)$borough

  p1 = aggregated_data_by_zone %>%
    filter(zone == z, variable == "Collisions") %>%
    ggplot(aes(x = year, y = total)) +
    geom_line(size = 1, color = nypd_blue) +
    geom_point(size = 3, color = nypd_blue) +
    geom_blank(aes(y = 0)) +
    geom_blank(aes(y = 1.4 * total)) +
    scale_x_continuous(breaks = c(2014, 2016, 2018)) +
    scale_y_continuous(labels = scales::comma) +
    ggtitle(
      paste(z, borough, sep = ", "),
      "Annual motor vehicle collisions"
    ) +
    labs(caption = "Data via NYPD\ntoddwschneider.com") +
    theme_tws(base_size = plot_bs) +
    theme(
      axis.title = element_blank(),
      panel.grid.minor.y = element_blank()
    )

  p2 = aggregated_data_by_zone %>%
    filter(zone == z, variable != "Collisions") %>%
    ggplot(aes(x = year, y = total)) +
    geom_line(size = 1, color = nypd_blue) +
    geom_point(size = 3, color = nypd_blue) +
    geom_blank(aes(y = 0)) +
    geom_blank(aes(y = 1.4 * total)) +
    scale_x_continuous(breaks = c(2014, 2016, 2018)) +
    scale_y_continuous(labels = scales::comma, breaks = integer_breaks(n = 3)) +
    facet_wrap(~variable, scales = "free_y", ncol = 2) +
    ggtitle(
      paste(z, borough, sep = ", "),
      "Annual injuries from motor vehicle collision"
    ) +
    labs(caption = "Data via NYPD\ntoddwschneider.com") +
    theme_tws(base_size = plot_bs) +
    theme(
      axis.title = element_blank(),
      panel.grid.minor.y = element_blank(),
      plot.subtitle = element_text(margin = unit(c(0, 0, 1.1, 0), "lines")),
      plot.margin = margin(plot_bs / 2, plot_bs * 0.75, plot_bs / 2, plot_bs / 2),
      axis.text = element_text(size = rel(0.7)),
      strip.text = element_text(size = rel(0.7))
    )

  png(paste0("graphs/zones/", zfile, "_collisions.png"), height = plot_width * 0.75, width = plot_width)
  print(p1)
  dev.off()

  png(paste0("graphs/zones/", zfile, "_injuries.png"), height = plot_width * 1.5, width = plot_width)
  print(p2)
  dev.off()
}



# find zones with steepest (positive or negative) trends
regressions_data = aggregated_data_by_zone %>%
  select(zone, borough, year, variable, total) %>%
  mutate(variable = gsub(" ", "_", tolower(variable))) %>%
  spread(variable, total)

slopes = purrr::map(zones, function(z) {
  df = filter(regressions_data, zone == z)

  tibble(
    zone = z,
    people_injured = lm(people_injured ~ year, data = df)$coef["year"],
    motorists_injured = lm(motorists_injured ~ year, data = df)$coef["year"],
    cyclists_injured = lm(cyclists_injured ~ year, data = df)$coef["year"],
    pedestrians_injured = lm(pedestrians_injured ~ year, data = df)$coef["year"]
  )
}) %>% bind_rows()

arrange(slopes, people_injured)
arrange(slopes, desc(people_injured))



# injury rates by time of day and alcohol involvement
alcohol_involved_unique_keys = query("
  SELECT DISTINCT collision_unique_key
  FROM collisions_contributing_factors
  WHERE contributing_factor LIKE '%alcohol%'
")$collision_unique_key

injury_rates_hourly = collisions %>%
  mutate(alcohol_involved = unique_key %in% alcohol_involved_unique_keys) %>%
  group_by(hour_of_day) %>%
  summarize(
    collisions = n(),
    frac_with_injury = mean(people_injured > 0),
    frac_with_fatality = mean(people_killed > 0),
    frac_with_alcohol_involvement = mean(alcohol_involved)
  ) %>%
  ungroup()

injury_rates_hourly = bind_rows(
  injury_rates_hourly,
  injury_rates_hourly %>%
    filter(hour_of_day == 0) %>%
    mutate(hour_of_day = 24)
)

p1 = ggplot(injury_rates_hourly, aes(x = hour_of_day, y = collisions)) +
  geom_line(size = 1, color = nypd_blue) +
  scale_x_continuous(breaks = c(0, 6, 12, 18, 24), labels = c("12 AM", "6 AM", "12 PM", "6 PM", "12 AM")) +
  scale_y_continuous(labels = scales::comma) +
  expand_limits(y = c(0, 125e3)) +
  ggtitle(
    "NYC collisions by time of day",
    "Jul 2012–Jan 2019"
  ) +
  labs(caption = "Data via NYPD\ntoddwschneider.com") +
  theme_tws(base_size = plot_bs) +
  no_axis_titles()

p2 = ggplot(injury_rates_hourly, aes(x = hour_of_day, y = frac_with_injury)) +
  geom_line(size = 1, color = nypd_blue) +
  scale_x_continuous(breaks = c(0, 6, 12, 18, 24), labels = c("12 AM", "6 AM", "12 PM", "6 PM", "12 AM")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  expand_limits(y = 0) +
  ggtitle(
    "Injury rate by time of day",
    "% of NYC collisions that result in injury"
  ) +
  labs(caption = "Data via NYPD, Jul 2012–Jan 2019\ntoddwschneider.com") +
  theme_tws(base_size = plot_bs) +
  no_axis_titles()

p3 = ggplot(injury_rates_hourly, aes(x = hour_of_day, y = frac_with_fatality)) +
  geom_line(size = 1, color = nypd_blue) +
  scale_x_continuous(breaks = c(0, 6, 12, 18, 24), labels = c("12 AM", "6 AM", "12 PM", "6 PM", "12 AM")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
  expand_limits(y = 0) +
  ggtitle(
    "Fatality rate by time of day",
    "% of NYC collisions that result in fatality"
  ) +
  labs(caption = "Data via NYPD, Jul 2012–Jan 2019\ntoddwschneider.com") +
  theme_tws(base_size = plot_bs) +
  no_axis_titles()

p4 = ggplot(injury_rates_hourly, aes(x = hour_of_day, y = frac_with_alcohol_involvement)) +
  geom_line(size = 1, color = nypd_blue) +
  scale_x_continuous(breaks = c(0, 6, 12, 18, 24), labels = c("12 AM", "6 AM", "12 PM", "6 PM", "12 AM")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  expand_limits(y = 0) +
  ggtitle(
    "Alcohol involvement by time of day",
    "% of NYC collisions with alcohol cited as contributing factor"
  ) +
  labs(caption = "Data via NYPD, Jul 2012–Jan 2019\ntoddwschneider.com") +
  theme_tws(base_size = plot_bs) +
  theme(plot.subtitle = element_text(size = rel(0.8))) +
  no_axis_titles()

png("graphs/collisions_by_hour.png", height = plot_width, width = plot_width)
print(p1)
dev.off()

png("graphs/injury_rate_by_hour.png", height = plot_width, width = plot_width)
print(p2)
dev.off()

png("graphs/fatality_rate_by_hour.png", height = plot_width, width = plot_width)
print(p3)
dev.off()

png("graphs/alcohol_involvement_by_hour.png", height = plot_width, width = plot_width)
print(p4)
dev.off()

alcohol_stats = collisions %>%
  mutate(alcohol_involved = unique_key %in% alcohol_involved_unique_keys) %>%
  group_by(alcohol_involved) %>%
  summarize(
    collisions = n(),
    frac_with_injury = mean(people_injured > 0),
    frac_with_fatality = mean(people_killed > 0)
  ) %>%
  ungroup()

injury_rates_alcohol = collisions %>%
  mutate(alcohol_involved = unique_key %in% alcohol_involved_unique_keys) %>%
  group_by(hour_of_day, alcohol_involved) %>%
  summarize(
    collisions = n(),
    frac_with_injury = mean(people_injured > 0),
    frac_with_fatality = mean(people_killed > 0)
  ) %>%
  ungroup()

injury_rates_alcohol = bind_rows(
  injury_rates_alcohol,
  injury_rates_alcohol %>%
    filter(hour_of_day == 0) %>%
    mutate(hour_of_day = 24)
)

p5 = ggplot(injury_rates_alcohol, aes(x = hour_of_day, y = frac_with_injury, color = alcohol_involved)) +
  geom_line(size = 1) +
  scale_x_continuous(breaks = c(0, 6, 12, 18, 24), labels = c("12 AM", "6 AM", "12 PM", "6 PM", "12 AM")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_color_manual(values = c(nypd_blue, "#49acd5"), guide = FALSE) +
  expand_limits(y = c(0, 0.4)) +
  annotate(
    "text", x = 17, y = 0.15, label = "Alcohol not cited",
    size = 8, color = nypd_blue, family = "Open Sans"
  ) +
  annotate(
    "text", x = 17, y = 0.34, label = "Alcohol cited",
    size = 8, color = "#49acd5", family = "Open Sans"
  ) +
  ggtitle(
    "Injury rate by alcohol involvement",
    "% of NYC collisions that result in injury"
  ) +
  labs(caption = "Data via NYPD, Jul 2012–Jan 2019\ntoddwschneider.com") +
  theme_tws(base_size = plot_bs) +
  no_axis_titles()

p6 = ggplot(injury_rates_alcohol, aes(x = hour_of_day, y = frac_with_fatality, color = alcohol_involved)) +
  geom_line(size = 1) +
  scale_x_continuous(breaks = c(0, 6, 12, 18, 24), labels = c("12 AM", "6 AM", "12 PM", "6 PM", "12 AM")) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
  scale_color_manual(values = c(nypd_blue, "#49acd5"), guide = FALSE) +
  expand_limits(y = c(0, 0.01)) +
  annotate(
    "text", x = 5, y = 0, label = "Alcohol not cited",
    size = 8, color = nypd_blue, family = "Open Sans"
  ) +
  annotate(
    "text", x = 5, y = 0.009, label = "Alcohol cited",
    size = 8, color = "#49acd5", family = "Open Sans"
  ) +
  ggtitle(
    "Fatality rate by alcohol involvement",
    "% of NYC collisions that result in fatality"
  ) +
  labs(caption = "Data via NYPD, Jul 2012–Jan 2019\ntoddwschneider.com") +
  theme_tws(base_size = plot_bs) +
  no_axis_titles()

png("graphs/injury_rate_by_alcohol_involvement.png", height = plot_width, width = plot_width)
print(p5)
dev.off()

png("graphs/fatality_rate_by_alcohol_involvement.png", height = plot_width, width = plot_width)
print(p6)
dev.off()
