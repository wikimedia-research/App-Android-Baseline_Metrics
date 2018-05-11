-- Extracts Android daily active users for T184095 & T184094
--
-- Parameters:
--   year  | UTC year
--   month | UTC month
--   day   | UTC day
--
-- Usage:
--   hive -f android_active_users.hql -d year=2018 -d month=1 -d day=1
--
-- Recommendation: --hiveconf mapred.job.queue.name=nice

SET parquet.compression = SNAPPY;
SET mapred.reduce.tasks = 4;

CREATE DATABASE IF NOT EXISTS bearloga;
CREATE TABLE IF NOT EXISTS bearloga.android_active_users (
  lyear           INT    COMMENT 'Unpadded year of request (localized to timezone)',
  lmonth          INT    COMMENT 'Unpadded month of request (localized to timezone)',
  lday            INT    COMMENT 'Unpadded day of request (localized to timezone)',
  lhour           INT    COMMENT 'Unpadded hour of request (localized to timezone)',
  uuid            STRING COMMENT 'appInstallId',
  version         STRING COMMENT '\'release\', \'beta\', etc.',
  country_code    STRING COMMENT 'IP-geolocated 2-character country code',
  country         STRING COMMENT 'IP-geolocated country name',
  subdivision     STRING COMMENT 'IP-geolocated subdivision',
  city            STRING COMMENT 'IP-geolocated city',
  timezone        STRING COMMENT 'IP-geolocated timezone (sometimes \'Unknown\')',
  wikipedia       STRING COMMENT 'Which Wikipedia user read (e.g. \'de\', \'fr\')',
  accept_language STRING COMMENT 'User\'s Accept-Language header',
  requests_count  BIGINT COMMENT 'Number of requests for the hour'
)
PARTITIONED BY (year INT, month INT, day INT)
STORED AS PARQUET;

INSERT OVERWRITE TABLE bearloga.android_active_users
  PARTITION (year = ${year}, month = ${month}, day = ${day})
  SELECT
    YEAR(FROM_UTC_TIMESTAMP(ts, geocoded_data['timezone'])) AS lyear,
    MONTH(FROM_UTC_TIMESTAMP(ts, geocoded_data['timezone'])) AS lmonth,
    DAY(FROM_UTC_TIMESTAMP(ts, geocoded_data['timezone'])) AS lday,
    HOUR(FROM_UTC_TIMESTAMP(ts, geocoded_data['timezone'])) AS lhour,
    COALESCE(x_analytics_map['wmfuuid'], PARSE_URL(concat('http://bla.org/woo/', uri_query), 'QUERY', 'appInstallID')) AS uuid,
    CASE WHEN INSTR(user_agent_map['wmf_app_version'], '-r-') > 0 THEN 'release'
         WHEN INSTR(user_agent_map['wmf_app_version'], '-beta-') > 0 THEN 'beta'
         WHEN INSTR(user_agent_map['wmf_app_version'], '-alpha-') > 0 THEN 'alpha'
         WHEN INSTR(user_agent_map['wmf_app_version'], '-amazon-') > 0 THEN 'amazon'
         WHEN INSTR(user_agent_map['wmf_app_version'], '-releasesprod-') > 0 THEN 'release'
         ELSE 'other' END AS version,
    geocoded_data['country_code'] AS country_code,
    geocoded_data['country'] AS country,
    geocoded_data['subdivision'] AS subdivision,
    geocoded_data['city'] AS city,
    geocoded_data['timezone'] AS timezone,
    normalized_host.project AS wikipedia,
    accept_language,
    COUNT(1) as requests_count
  FROM wmf.webrequest
  WHERE webrequest_source = 'text'
    AND year = ${year} AND month = ${month} AND day = ${day}
    AND agent_type = 'user'
    AND access_method = 'mobile app'
    AND user_agent_map['os_family'] = 'Android'
    AND (
        (PARSE_URL(CONCAT('http://bla.org/woo/', uri_query), 'QUERY', 'action') = 'mobileview' AND uri_path == '/w/api.php')
        OR (uri_path LIKE '/api/rest_v1%' AND uri_query == '')
    )
    AND COALESCE(x_analytics_map['wmfuuid'], PARSE_URL(CONCAT('http://bla.org/woo/', uri_query), 'QUERY', 'appInstallID')) IS NOT NULL
    AND normalized_host.project_class = 'wikipedia'
  GROUP BY
    YEAR(FROM_UTC_TIMESTAMP(ts, geocoded_data['timezone'])),
    MONTH(FROM_UTC_TIMESTAMP(ts, geocoded_data['timezone'])),
    DAY(FROM_UTC_TIMESTAMP(ts, geocoded_data['timezone'])),
    HOUR(FROM_UTC_TIMESTAMP(ts, geocoded_data['timezone'])),
    COALESCE(x_analytics_map['wmfuuid'], PARSE_URL(concat('http://bla.org/woo/', uri_query), 'QUERY', 'appInstallID')),
    CASE WHEN INSTR(user_agent_map['wmf_app_version'], '-r-') > 0 THEN 'release'
         WHEN INSTR(user_agent_map['wmf_app_version'], '-beta-') > 0 THEN 'beta'
         WHEN INSTR(user_agent_map['wmf_app_version'], '-alpha-') > 0 THEN 'alpha'
         WHEN INSTR(user_agent_map['wmf_app_version'], '-amazon-') > 0 THEN 'amazon'
         WHEN INSTR(user_agent_map['wmf_app_version'], '-releasesprod-') > 0 THEN 'release'
         ELSE 'other' END,
    geocoded_data['country_code'],
    geocoded_data['country'],
    geocoded_data['subdivision'],
    geocoded_data['city'],
    geocoded_data['timezone'],
    normalized_host.project,
    accept_language
;
