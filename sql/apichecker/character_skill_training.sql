CREATE TABLE IF NOT EXISTS `character_skill_training` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `character_id` bigint(20) NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime NOT NULL,
  `skill_id` int(11) NOT NULL,
  `start_sp` int(11) NOT NULL,
  `end_sp` int(11) NOT NULL,
  `to_level` int(11) NOT NULL,
  `current_tq_time` datetime NOT NULL,
  `offset` int(11) NOT NULL,
  `cached_until` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `character_id` (`character_id`),
  KEY `skill_id` (`skill_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;