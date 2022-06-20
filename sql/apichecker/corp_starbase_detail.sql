CREATE TABLE IF NOT EXISTS `corp_starbase_detail` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `starbase_id` bigint(20) NOT NULL,
    `online_timestamp` datetime NULL,
    `state_timestamp` datetime NULL,
    `state` int(11) NOT NULL,
    `cached_until` datetime NOT NULL,
    `allow_corporation_members` int(1) NOT NULL,
    `allow_alliance_members` int(1) NOT NULL,
    `usage_flags` int(1) NOT NULL,
    `deploy_flags` int(1) NOT NULL,
    `on_status_drop_standing` int(1) NOT NULL,
    `on_corporation_war` int(1) NOT NULL,
    `on_aggression` int(1) NOT NULL,
    `on_status_drop_enabled` int(1) NOT NULL,
    `on_standing_drop` int(1) NOT NULL,
    `use_standings_from` int(1) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `state` (`state`),
    KEY `usage_flags` (`usage_flags`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;


CREATE TABLE IF NOT EXISTS `corp_starbase_detail_fuel` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `starbase_id` bigint(20) NOT NULL, 
    `type_id` int(11) NOT NULL,
    `quantity` int(11) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `starbase_id` (`starbase_id`),
    KEY `type_id` (`type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;