DROP TABLE IF EXISTS `structures`;
CREATE TABLE IF NOT EXISTS `structures` (
  `structure_id` bigint(20) NOT NULL,
  `name` varchar(100) NOT NULL,
  `solar_system_id` bigint(20) NOT NULL,
  `x` bigint(20) NOT NULL,
  `y` bigint(20) NOT NULL,
  `z` bigint(20) NOT NULL,
  `type_id` int(11) NOT NULL,
  PRIMARY KEY (`structure_id`),
  KEY `solar_system_id` (`solar_system_id`),
  KEY `type_id` (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;