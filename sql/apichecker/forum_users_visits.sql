CREATE TABLE IF NOT EXISTS `forum_users_visits` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `userid` int(10) NOT NULL,
  `date` datetime NOT NULL,
  `ip` varchar(25) NOT NULL,

  PRIMARY KEY (`id`),
  KEY `userid` (`userid`),
  KEY `ip` (`ip`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
