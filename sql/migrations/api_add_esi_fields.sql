ALTER TABLE  `api_key_info` ADD  `access_token` varchar(200) NULL;
ALTER TABLE  `api_key_info` ADD  `refresh_token` varchar(500) NULL;
ALTER TABLE  `api_key_info` ADD  `expires_in` datetime NULL;