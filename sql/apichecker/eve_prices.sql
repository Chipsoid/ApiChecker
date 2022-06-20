CREATE TABLE IF NOT EXISTS `eve_prices` (
  `type_id` bigint(20) NOT NULL,
  `average` double(20,2) NOT NULL,
  `adjusted` double(20,2) NOT NULL,
  `date` datetime NOT NULL,
  PRIMARY KEY (`type_id`),
  KEY `date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;