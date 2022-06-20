CREATE TABLE IF NOT EXISTS `character_contract_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `character_id` bigint(20) NOT NULL,
  `contract_id` bigint(20) NOT NULL,
  `record_id` bigint(20) NOT NULL,
  `type_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL,
  `raw_quantity` int(11) DEFAULT NULL,
  `singleton` int(11) NOT NULL,
  `included` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `character_id` (`character_id`),
  KEY `contract_id` (`contract_id`),
  KEY `type_id` (`type_id`),
  KEY `record_id` (`record_id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;