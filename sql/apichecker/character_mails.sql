CREATE TABLE IF NOT EXISTS `character_mails` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `character_id` bigint(20) NOT NULL,
  `message_id` bigint(20) NOT NULL,
  `to_character_ids` varchar(500) NOT NULL,
  `sender_id` bigint(20) NOT NULL,
  `sender_name` varchar(100) NOT NULL,
  `sent_date` datetime NOT NULL,
  `to_corp_or_alliance_id` varchar(500) NOT NULL,
  `title` varchar(500) NOT NULL,
  `body` text NOT NULL,
  `to_list_id` bigint(20) NOT NULL,
  `cached_until` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `character_id` (`character_id`),
  KEY `message_id` (`message_id`),
  KEY `sender_id` (`sender_id`),
  KEY `cached_until` (`cached_until`),
  KEY `to_list_id` (`to_list_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;