CREATE TABLE IF NOT EXISTS `account_status` (
  `key_id` int(11) NOT NULL,
  `paid_until` datetime NOT NULL,
  `create_date` datetime NOT NULL,
  `logon_count` int(11) NOT NULL,
  `logon_minutes` int(11) NOT NULL,
  `cached_until` datetime NOT NULL,
  PRIMARY KEY (`key_id`),
  KEY `key_id` (`key_id`,`cached_until`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;