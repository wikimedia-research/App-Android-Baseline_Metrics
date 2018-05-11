# Extract & refine Android users' webrequests (one request per hour per user)
#
# > DESCRIBE bearloga.android_active_users;
# lyear               	int                 	Unpadded year of request (localized to timezone)
# lmonth              	int                 	Unpadded month of request (localized to timezone)
# lday                	int                 	Unpadded day of request (localized to timezone)
# lhour               	int                 	Unpadded hour of request (localized to timezone)
# uuid                	string              	appInstallId        
# version             	string              	'release', 'beta', etc.
# country_code        	string              	IP-geolocated 2-character country code
# country             	string              	IP-geolocated country name
# subdivision           string                IP-geolocated subdivision
# city                  string                IP-geolocated city
# timezone            	string              	IP-geolocated timezone (sometimes 'Unknown')
# wikipedia           	string              	Which Wikipedia user read (e.g. 'de', 'fr')
# accept_language     	string              	User' accept language
# requests_count        bigint                Number of requests for the hour
#
# Partitioned on UTC-based year, month, day

# Run remotely on stat1005:
start_date <- as.Date("2018-01-31") # to avoid left-trimming on 2018-02-01
end_date <- as.Date("2018-05-11") # to avoid right-trimming on 2018-05-10
dates <- seq(start_date, end_date, by = "day")
for (i in 1:length(dates)) {
  date <- dates[i]
  message("Extracting & refining Android users' webrequests from ", format(date))
  year <- lubridate::year(date)
  month <- lubridate::month(date)
  day <- lubridate::mday(date)
  cmd <- glue::glue("hive --hiveconf mapred.job.queue.name=nice -S -f android_active_users.hql -d year={year} -d month={month} -d day={day}")
  message("Executing `", cmd, "`")
  system(cmd)
}
