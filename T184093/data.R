library(dplyr)
# Create an auto-closing SSH tunnel in the background...
# See https://gist.github.com/scy/6781836 for more info.
system("ssh -f -o ExitOnForwardFailure=yes stat1006.eqiad.wmnet -L 3307:analytics-slave.eqiad.wmnet:3306 sleep 10")
library(RMySQL)
con <- dbConnect(MySQL(), host = "127.0.0.1", group = "client", dbname = "log", port = 3307)

# Only users navigated to the feed customization screen
query <- "
SELECT last_config.timestamp, last_config.event_appInstallID, event_enabledList, event_orderList
FROM MobileWikiAppFeedConfigure_17490595 AS all_config
RIGHT JOIN
(SELECT MAX(timestamp) AS timestamp, event_appInstallID
FROM MobileWikiAppFeedConfigure_17490595
WHERE INSTR(userAgent, 'Android') > 0
AND userAgent LIKE '%-r-%'
AND LEFT(timestamp, 8) >= '20171209'
GROUP BY event_appInstallID) AS last_config
ON (all_config.timestamp=last_config.timestamp AND all_config.event_appInstallID=last_config.event_appInstallID)
"
feed_last_config <- wmf::mysql_read(query, "log", con = con)
wmf::mysql_close(con)
# De-duplicate
feed_last_config <- feed_last_config %>%
  arrange(event_appInstallID, timestamp, desc(event_enabledList), event_orderList)
dup_mask <- duplicated(feed_last_config$event_appInstallID, fromLast = TRUE)
feed_last_config <- feed_last_config[!dup_mask, ]
save(feed_last_config, file = "data/feed_last_config.RData")

# Get DAU
# spark2R --master yarn --executor-memory 2G --executor-cores 1 --driver-memory 4G
query <- "
SELECT CONCAT(year,'-',LPAD(month,2,'0'),'-',LPAD(day,2,'0')) as date,
unique_count AS Android_DAU
FROM wmf.mobile_apps_uniques_daily
WHERE platform = 'Android'
AND ((year=2017 AND month=12) OR (year=2018 AND month>=1))
"
dau <- collect(sql(query))
dau$date <- lubridate::ymd(dau$date)
save(dau, file="data/android/dau.RData")
system("scp chelsyx@stat5:~/data/android/dau.RData data/.")

# Daily feed config
query <- "
SELECT last_config.date, last_config.timestamp, last_config.event_appInstallID, event_enabledList, event_orderList
FROM MobileWikiAppFeedConfigure_17490595 AS all_config
RIGHT JOIN
(SELECT LEFT(timestamp, 8) AS date, MAX(timestamp) AS timestamp, event_appInstallID
FROM MobileWikiAppFeedConfigure_17490595
WHERE INSTR(userAgent, 'Android') > 0
AND userAgent LIKE '%-r-%'
AND LEFT(timestamp, 8) >= '20171209'
AND (event_enabledList != '1,1,1,1,1,1,1,1,1'
OR event_orderList != '0,1,2,3,4,5,6,7,8')
GROUP BY LEFT(timestamp, 8), event_appInstallID) AS last_config
ON (all_config.timestamp=last_config.timestamp AND all_config.event_appInstallID=last_config.event_appInstallID)
"
daily_feed_config <- wmf::mysql_read(query, "log", con = con)
wmf::mysql_close(con)
# De-duplicate
daily_feed_config <- unique(daily_feed_config)
daily_feed_config <- daily_feed_config %>%
  arrange(date, event_appInstallID, timestamp, desc(event_enabledList), event_orderList)
dup_mask <- duplicated(daily_feed_config[, c("date", "event_appInstallID")], fromLast = TRUE)
daily_feed_config <- daily_feed_config[!dup_mask, ]
daily_feed_config$date <- lubridate::ymd(daily_feed_config$date)
save(daily_feed_config, file = "data/daily_feed_config.RData")
