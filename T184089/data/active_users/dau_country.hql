SET mapred.job.queue.name=nice;
USE wmf;
WITH mobile_apps_uuids AS (
  SELECT
    year, month, day,
    CASE WHEN (user_agent LIKE '%iOS%' OR user_agent LIKE '%iPhone%') THEN 'iOS' ELSE 'Android' END AS platform,
    COALESCE(x_analytics_map['wmfuuid'], parse_url(concat('http://bla.org/woo/', uri_query), 'QUERY', 'appInstallID')) AS uuid,
    geocoded_data['country'] AS country,
    geocoded_data['country_code'] AS country_code
  FROM webrequest
  WHERE user_agent LIKE('WikipediaApp%')
    AND ((parse_url(concat('http://bla.org/woo/', uri_query), 'QUERY', 'action') = 'mobileview' AND uri_path == '/w/api.php') OR (uri_path LIKE '/api/rest_v1%' AND uri_query == ''))
    AND COALESCE(x_analytics_map['wmfuuid'], parse_url(concat('http://bla.org/woo/', uri_query), 'QUERY', 'appInstallID')) IS NOT NULL
    AND webrequest_source IN ('text')
    AND year = ${year}
    AND month = ${month}
    AND day = ${day}
)
SELECT
  year, month, day, platform, country, country_code,
  COUNT(DISTINCT uuid) AS unique_count
FROM
  mobile_apps_uuids
GROUP BY
  year, month, day, platform, country, country_code;
