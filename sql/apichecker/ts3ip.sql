CREATE TABLE IF NOT EXISTS `ts3ip` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `client_id` int(11) NOT NULL,
  `last_login` int(11) NOT NULL,
  `ip` varchar(25) NOT NULL,
  `upload_date` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `client_id` (`client_id`),
  KEY `last_login` (`last_login`),
  KEY `ip` (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS `ts3users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `client_id` int(11) NOT NULL,
  `unique_id` varchar(255) NOT NULL,
  `nickname` varchar(255) NOT NULL,
  `create_date` int(11) NOT NULL,
  `login_count` int(11) NOT NULL,
  `desc` text NULL,
  `upload_date` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `client_id` (`client_id`),
  KEY `nickname` (`nickname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;