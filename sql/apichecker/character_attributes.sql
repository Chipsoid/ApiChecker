CREATE TABLE IF NOT EXISTS `character_attributes` (
  `character_id` int(11) NOT NULL,
  `memory` tinyint(4) NOT NULL,
  `intelligence` tinyint(4) NOT NULL,
  `charisma` tinyint(4) NOT NULL,
  `willpower` tinyint(4) NOT NULL,
  `perception` tinyint(4) NOT NULL,
  `cached_until` datetime NOT NULL,
  PRIMARY KEY (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;