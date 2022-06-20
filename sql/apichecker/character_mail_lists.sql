CREATE TABLE IF NOT EXISTS `character_mail_lists` (
  `mail_list_id` bigint(20) NOT NULL,
  `character_id` bigint(20) NOT NULL,
  `mail_list_name` varchar(100) NOT NULL,
  `cached_until` datetime NOT NULL,
  KEY `mail_list_id` (`mail_list_id`,`character_id`),
  KEY `cached_until` (`cached_until`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;