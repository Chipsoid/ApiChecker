CREATE TABLE IF NOT EXISTS `corp_api` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `corporation_id` bigint(20) NOT NULL,
  `mask`   bigint(20) NOT NULL,
  `status` tinyint(4) NOT NULL,
  `key_id` int(11) NOT NULL,
  `vCode` varchar(200) NOT NULL,
  `user_id` int(11) NOT NULL,
  `added` datetime NOT NULL,
  `deleted` int(1) NOT NULL default 0,
  PRIMARY KEY (`id`),
  KEY `key_id`  (`key_id`),
  KEY `user_id` (`user_id`),
  KEY `deleted` (`deleted`),
  KEY `status`  (`status`),
  KEY `corporation_id` (`corporation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;