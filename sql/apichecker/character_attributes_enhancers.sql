CREATE TABLE IF NOT EXISTS `character_attribute_enhancers` (
  `character_id` int(11) NOT NULL,
  `attribute` varchar(50) NOT NULL,
  `name` varchar(50) NOT NULL,
  `value` int(11) NOT NULL,
  `cached_until` datetime NOT NULL,
  INDEX (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;