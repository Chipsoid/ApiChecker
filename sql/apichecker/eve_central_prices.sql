CREATE TABLE IF NOT EXISTS `eve_central_prices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type_id` bigint(20) NOT NULL,
  `station_id` int(11) NOT NULL,
  `type` enum('all','buy','sell') NOT NULL,
  `stddev` float(8,2) NOT NULL,
  `volume` bigint(20) NOT NULL,
  `percentile` float(3,2) NOT NULL,
  `average` double(20,2) NOT NULL,
  `min` double(20,2) NOT NULL,
  `max` double(20,2) NOT NULL,
  `median` double(20,2) NOT NULL,
  `date` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `type_id` (`type_id`),
  KEY `type` (`type`),
  KEY `station_id` (`station_id`),
  KEY `date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;