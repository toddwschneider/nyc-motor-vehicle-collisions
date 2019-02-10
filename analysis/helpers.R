required_packages = c("tidyverse", "scales", "lubridate", "RPostgres", "zoo")
installed_packages = rownames(installed.packages())
packages_to_install = required_packages[!(required_packages %in% installed_packages)]

if (length(packages_to_install) > 0) {
  install.packages(
    packages_to_install,
    dependencies = TRUE,
    repos = "https://cloud.r-project.org",
  )
}

library(tidyverse)
library(scales)
library(lubridate)
library(zoo)
library(RPostgres)

con = dbConnect(
  dbDriver("Postgres"),
  dbname = "nyc-motor-vehicle-collisions",
  host = "localhost"
)

query = function(sql) {
  res = dbSendQuery(con, sql)
  results = dbFetch(res) %>% as_tibble()
  dbClearResult(res)
  results
}

capitalize_first_letter = function(string) {
  paste0(toupper(substr(string, 1, 1)), substr(string, 2, nchar(string)))
}

theme_void_sf = function(base_size = 12) {
  theme_void(base_size = base_size) +
    theme(
      panel.grid = element_line(size = 0),
      text = element_text(family = "Open Sans")
    )
}

font_family = "Open Sans"
title_font_family = "Fjalla One"
nypd_blue = "#00003c"

theme_tws = function(base_size = 12) {
  bg_color = "#f4f4f4"
  bg_rect = element_rect(fill = bg_color, color = bg_color)

  theme_bw(base_size) +
    theme(
      text = element_text(family = font_family),
      plot.title = element_text(family = title_font_family),
      plot.subtitle = element_text(size = rel(1)),
      plot.caption = element_text(size = rel(0.5), margin = unit(c(1, 0, 0, 0), "lines"), lineheight = 1.1, color = "#555555"),
      plot.background = bg_rect,
      axis.ticks = element_blank(),
      axis.text.x = element_text(size = rel(1)),
      axis.title.x = element_text(size = rel(1), margin = margin(1, 0, 0, 0, unit = "lines")),
      axis.text.y = element_text(size = rel(1)),
      axis.title.y = element_text(size = rel(1)),
      panel.background = bg_rect,
      panel.border = element_blank(),
      panel.grid.major = element_line(color = "grey80", size = 0.25),
      panel.grid.minor = element_line(color = "grey80", size = 0.25),
      panel.spacing = unit(1.5, "lines"),
      legend.background = bg_rect,
      legend.key.width = unit(1.5, "line"),
      legend.key = element_blank(),
      strip.background = element_blank()
    )
}

no_axis_titles = function() {
  theme(axis.title = element_blank())
}

# via https://stackoverflow.com/a/10559838
integer_breaks = function(n = 3, ...) {
  breaker = pretty_breaks(n, ...)
  function(x) {
     breaks = breaker(x)
     breaks[breaks == floor(breaks)]
  }
}
