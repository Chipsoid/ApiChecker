CREATE TABLE IF NOT EXISTS `corp_contacts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `corp_or_ally_id` bigint(20) NOT NULL,
  `contact_id` bigint(20) NOT NULL,
  `contact_name` varchar(50) NOT NULL,
  `contact_type_id` int(11) NOT NULL,
  `standing` float(5,2) NOT NULL,
  `cached_until` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `corp_or_ally_id` (`corp_or_ally_id`),
  KEY `contact_id` (`contact_id`),
  KEY `cached_until` (`cached_until`),
  KEY `standing` (`standing`),
  KEY `contact_type_id` (`contact_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;