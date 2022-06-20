CREATE TABLE IF NOT EXISTS `character_implants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `character_id` bigint(20) NOT NULL,
  `type_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `character_id` (`character_id`),
  KEY `type_id` (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;