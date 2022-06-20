CREATE TABLE IF NOT EXISTS `character_skills` (
  `character_id` int(11) NOT NULL,
  `type_id` int(11) NOT NULL,
  `skill_points` int(11) NOT NULL,
  `level` tinyint(4) NOT NULL,
  `cached_until` datetime NOT NULL,
  PRIMARY KEY (`character_id`,`type_id`),
  KEY `level` (`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;