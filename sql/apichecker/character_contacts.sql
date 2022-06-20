CREATE TABLE IF NOT EXISTS `character_contacts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `character_id` bigint(20) NOT NULL,
  `contact_id` bigint(20) NOT NULL,
  `contact_name` varchar(50) NOT NULL,
  `contact_type_id` int(11) NOT NULL,
  `standing` int(11) NOT NULL,
  `in_watchlist` tinyint(4) DEFAULT NULL,
  `cached_until` datetime NOT NULL,
  `added_date` datetime NOT NULL,
  `archived_date`  datetime  NULL,
  PRIMARY KEY (`id`),
  KEY `character_id` (`character_id`),
  KEY `contact_id` (`contact_id`),
  KEY `cached_until` (`cached_until`),
  KEY `standing` (`standing`),
  KEY `contact_type_id` (`contact_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;