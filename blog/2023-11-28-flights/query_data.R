# load libraries
library(tidyverse)
library(anyflights)

# query data on flights, weather, planes, etc for all
# out-bound flights from Madison, WI in 2022.
msnflights22_raw <- anyflights("MSN", 2022)

save(msnflights22_raw, file = "example/data/msnflights22_raw.rda")

msnflights22 <-
  # start with weather data, selecting off relevant columns
  msnflights22_raw$weather %>%
  select(origin, year, month, day, hour, precip, wind_speed, visibility = visib) %>%
  # join to flight data
  right_join(msnflights22_raw$flights, by = c("origin", "year", "month", "day", "hour")) %>%
  # join to airline data to get full carrier name
  left_join(msnflights22_raw$airlines, by = c("carrier")) %>%
  select(-carrier, airline = name) %>%
  # select, rename, and restructure columns
  mutate(date = make_date(year, month, day),
         duration = air_time,
         flight = as.factor(flight),
         plane = tailnum,
         destination = dest,
         delayed = case_when(dep_delay > 10 | is.infinite(dep_delay) ~ "Yes", .default = "No"),
         delayed = factor(delayed, levels = c("Yes", "No")),
         precip = case_when(is.na(precip) ~ 0, .default = precip)
  ) %>%
  select(airline, flight, origin, destination, date, hour, 
         plane, distance, duration, wind_speed, precip, visibility, delayed) %>%
  left_join(
    .,
    select(msnflights22_raw$planes, plane = tailnum, plane_year = year),
    by = "plane"
  ) %>%
  mutate(
    across(where(is.character), ~ as.factor(.x)),
    airline = as.character(airline)
  ) %>%
  relocate(delayed, .before = everything()) %>%
  filter(!is.na(delayed))

save(msnflights22, file = "example/data/msnflights22.rda")
