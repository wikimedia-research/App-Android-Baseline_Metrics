# spark2R --master yarn --executor-memory 2G --executor-cores 1 --driver-memory 4G

query <- "SELECT year, month, day, wiki, 
avg(event.totalPages) AS mean_pages,
percentile(cast(event.totalPages as BIGINT), 0.5) AS median_pages,
avg(event.length) AS mean_time,
percentile(cast(event.length as BIGINT), 0.5) AS median_time
FROM event.mobilewikiappsessions
WHERE useragent.os_family = 'Android'
GROUP BY year, month, day, wiki
"
android_session <- collect(sql(query))
save(android_session, file="data/android/android_session.RData")
# Android only. Where is iOS?

system("scp chelsyx@stat5:~/data/android/android_session.RData data/")
load("data/android_session.RData")
