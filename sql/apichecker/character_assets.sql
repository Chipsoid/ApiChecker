CREATE TABLE `character_assets` (
 `id` int(11) NOT NULL AUTO_INCREMENT,
 `character_id` int(11) NOT NULL,
 `item_id` bigint(20) NOT NULL,
 `location_id` bigint(20) NOT NULL,
 `type_id` int(11) NOT NULL,
 `quantity` int(11) NOT NULL,
 `flag` int(11) NOT NULL,
 `singleton` tinyint(2) NOT NULL,
 `raw_quantity` int(11) NOT NULL,
 `cached_until` datetime NOT NULL,
 `contents` bigint(20) NOT NULL,
 PRIMARY KEY (`id`),
 KEY `character_id` (`character_id`),
 KEY `type_id` (`type_id`),
 KEY `location_id` (`location_id`),
 KEY `contents` (`contents`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=UTF8