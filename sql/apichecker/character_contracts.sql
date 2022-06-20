
CREATE TABLE IF NOT EXISTS `character_contracts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `character_id` bigint(20) NOT NULL,
  `contract_id` int(11) NOT NULL,
  `issuer_id` bigint(20) DEFAULT NULL,
  `issuer_corp_id` bigint(20) DEFAULT NULL,
  `assignee_id` bigint(20) DEFAULT NULL,
  `acceptor_id` bigint(20) DEFAULT NULL,
  `start_station_id` int(11) DEFAULT NULL,
  `end_station_id` int(11) DEFAULT NULL,
  `type` varchar(50) NOT NULL,
  `status` varchar(50) NOT NULL,
  `title` varchar(250) NOT NULL,
  `for_corp` int(11) DEFAULT NULL,
  `availability` varchar(50) NOT NULL,
  `date_issued` datetime DEFAULT NULL,
  `date_expired` datetime DEFAULT NULL,
  `date_accepted` datetime DEFAULT NULL,
  `num_days` int(11) DEFAULT NULL,
  `date_completed` datetime DEFAULT NULL,
  `price` decimal(16,2) DEFAULT NULL,
  `reward` decimal(16,2) DEFAULT NULL,
  `collateral` decimal(16,2) DEFAULT NULL,
  `buyout` decimal(16,2) DEFAULT NULL,
  `volume` int(11) DEFAULT NULL,
  `cached_until` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `character_id` (`character_id`),
  KEY `contract_id` (`contract_id`),
  KEY `issuer_id` (`issuer_id`),
  KEY `issuer_corp_id` (`issuer_corp_id`),
  KEY `assignee_id` (`assignee_id`),
  KEY `acceptor_id` (`acceptor_id`),
  KEY `type` (`type`),
  KEY `status` (`status`),
  KEY `availability` (`availability`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;