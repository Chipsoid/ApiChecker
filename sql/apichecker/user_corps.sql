CREATE TABLE IF NOT EXISTS `user_corps` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `corporation_id` bigint(20) NOT NULL,
  PRIMARY KEY (`id`),
 KEY `user_id` (`user_id`),
 KEY `corporation_id` (`corporation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;