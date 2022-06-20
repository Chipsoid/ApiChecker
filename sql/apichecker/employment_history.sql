CREATE TABLE `employment_history` (
 `record_id` bigint(20) NOT NULL,
 `character_id` bigint(20) NOT NULL,
 `corporation_id` bigint(20) NOT NULL,
 `corporation_name` varchar(50) NOT NULL,
 `start_date` datetime NOT NULL,
 `cached_until` datetime NOT NULL,
 PRIMARY KEY (`record_id`),
 KEY `character_id` (`character_id`),
 KEY `corporation_id` (`corporation_id`),
 KEY `cached_until` (`cached_until`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8