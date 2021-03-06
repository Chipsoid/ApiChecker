CREATE TABLE IF NOT EXISTS `api_key_info` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `key_id` int(11) NOT NULL,
  `access_mask` int(11) NOT NULL,
  `type` varchar(25) NOT NULL,
  `expires` datetime DEFAULT NULL,
  `character_id` int(11) NOT NULL,
  `character_name` varchar(50) NOT NULL,
  `corporation_id` int(11) NOT NULL,
  `corporation_name` varchar(80) NOT NULL,
  `alliance_id` int(11) DEFAULT NULL,
  `alliance_name` varchar(80) DEFAULT NULL,
  `faction_id` int(11) DEFAULT NULL,
  `faction_name` varchar(80) DEFAULT NULL,
  `cached_until` datetime NOT NULL,
  `access_token` varchar(100) NULL,
  `refresh_token` varchar(500) NULL,
  `expires_in` datetime NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `character_id` (`character_id`),
  KEY `key_id` (`key_id`,`corporation_id`,`alliance_id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;