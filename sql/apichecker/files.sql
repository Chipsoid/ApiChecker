CREATE TABLE IF NOT EXISTS `files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `hash` varchar(32) NOT NULL,
  `filename` varchar(255) NOT NULL,
  `ext` varchar(11) NOT NULL,
  `size` int(11) NOT NULL,
  `path` varchar(255) NOT NULL,
  `upload_date` datetime NOT NULL,
  `uploaded_by` varchar(255) NOT NULL,
  `enabled` int(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `hash` (`hash`),
  KEY `filename` (`filename`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS `file_downloads` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `file_id` int(32) NOT NULL,
  `date` datetime NOT NULL,
  `ip` varchar(120) NOT NULL,
  `who` varchar(255) NOT NULL,
  `ua` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `file_id` (`file_id`),
  KEY `ip` (`ip`),
  KEY `date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1;