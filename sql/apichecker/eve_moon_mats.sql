CREATE TABLE IF NOT EXISTS `eve_moon_mats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mat_type_id` int(11) NOT NULL,
  `location_id` bigint(20) NOT NULL,
  `moon_item_id`  int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `mat_type_id`  (`mat_type_id`),
  KEY `location_id`  (`location_id`),
  KEY `moon_item_id` (`moon_item_id`),
  UNIQUE `moon_info` (`moon_item_id`,`mat_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;