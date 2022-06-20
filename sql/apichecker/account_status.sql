CREATE TABLE IF NOT EXISTS `character_sheet` (
  `character_id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `race` varchar(10) NOT NULL,
  `gender` varchar(10) NOT NULL,
  `blood_line` varchar(20) NOT NULL,
  `ancestry` varchar(20) NOT NULL,
  `clone_name` varchar(50) NOT NULL,
  `clone_skill_points` int(11) NOT NULL,
  `date_of_birth` datetime NOT NULL,
  `balance` bigint(20) NOT NULL,
  `cached_until` datetime NOT NULL,
  `is_bigboy` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`character_id`),
  KEY `is_bigboy` (`is_bigboy`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;