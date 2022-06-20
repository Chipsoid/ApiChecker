CREATE TABLE `users` (  
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,  
    `login` varchar(100) COLLATE utf8_bin NOT NULL,  
    `password` varchar(100) COLLATE utf8_bin NOT NULL,  
    `last_login` datetime NOT NULL,  
    `created` datetime NOT NULL,  
    `status` tinyint(4) NOT NULL,
    `login_count` int(11) NOT NULL DEFAULT '0',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci