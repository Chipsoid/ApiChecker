DROP TABLE IF EXISTS `facilities`;
CREATE TABLE IF NOT EXISTS `facilities` (
  `facility_id` bigint(20) NOT NULL,
  `owner_id` bigint(20) NOT NULL,
  `region_id` bigint(20) NOT NULL,
  `solar_system_id` bigint(20) NOT NULL,
  `tax` double(3,2) NULL,
  `type_id` int(11) NOT NULL,
  PRIMARY KEY (`facility_id`),
  KEY `owner_id` (`owner_id`),
  KEY `solar_system_id` (`solar_system_id`),
  KEY `type_id` (`type_id`),
  KEY `region_id` (`region_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;