# wmf.mobile_apps_uniques_daily is a count of unique devices per day
# wmf.mobile_apps_uniques_monthly is a count of unique devices per month

# == OVERALL DAU/MAU ==
# We should use the last day of every month for DAU to pair it with the MAU for that month.
# This will give us overall (not broken down by market) stickiness % for both platforms.
# Remotely on stat1005:
overall_query <- "USE wmf;
SELECT
  TO_DATE(CONCAT(
    mobile_apps_uniques_daily.year, '-',
    LPAD(mobile_apps_uniques_daily.month, 2, '0'), '-',
    LPAD(mobile_apps_uniques_daily.day, 2, '0')
  )) AS date,
  mobile_apps_uniques_daily.platform AS platform,
  mobile_apps_uniques_daily.unique_count AS dau,
  mobile_apps_uniques_monthly.unique_count AS mau
FROM mobile_apps_uniques_daily
LEFT JOIN mobile_apps_uniques_monthly ON (
  mobile_apps_uniques_daily.year >= 2017
  AND mobile_apps_uniques_daily.year = mobile_apps_uniques_monthly.year
  AND mobile_apps_uniques_daily.month = mobile_apps_uniques_monthly.month
  AND mobile_apps_uniques_daily.platform = mobile_apps_uniques_monthly.platform
)
WHERE mobile_apps_uniques_monthly.unique_count IS NOT NULL;"
active_users <- wmf::query_hive(overall_query)
readr::write_csv(active_users, "~/overall_active_users.csv")
# Locally:
system("scp stat5:/home/bearloga/overall_active_users.csv T184089/data/")

# == ROLLING ==
# For a DAU/MAU broken down by market, we'll need to run some custom queries until T186828 is resolved.
# Upload queries via `system("scp -r T184089/data/active_users/*_country.hql stat5:/home/bearloga/")`,
# then run remotely on stat1005:
start_date <- as.Date("2017-12-01"); end_date <- as.Date("2018-02-11")
for (active_users in c("dau", "mau")) {
  query <- paste0(readr::read_lines(glue::glue("~/{active_users}_country.hql")), collapse = "\n")
  results <- lapply(
    seq(start_date, end_date, by = ifelse(active_users == "mau", "month", "day")),
    function(date) {
      message("Counting ", toupper(active_users), " from ", format(date))
      # Substitute variables:
      year <- lubridate::year(date)
      month <- lubridate::month(date, label = FALSE)
      day <- lubridate::mday(date)
      query <- glue::glue(query, .open = "${", .close = "}")
      # Run query:
      result <- try(wmf::query_hive(query))
      if (inherits(result, "try-error")) {
        warning("Error getting data from ", format(date))
        return(NULL)
      } else {
        return(result)
      }
    })
  readr::write_csv(do.call(rbind, results), glue::glue("~/{active_users}_country.csv"))
}; rm(active_users, query, results, start_date, end_date)
# Then copy queried data to local repo:
# `system("scp -r stat5:/home/bearloga/*au_country.csv T184089/data/active_users/")`
