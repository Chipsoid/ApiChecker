DROP TABLE IF EXISTS `ref_types`;

CREATE TABLE IF NOT EXISTS `ref_types` (
  `ref_id` int(11) NOT NULL,
  `ref_name` varchar(50) NOT NULL,
  PRIMARY KEY (`ref_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Дамп данных таблицы `ref_types`
--

INSERT INTO `ref_types` (`ref_id`, `ref_name`) VALUES
(1, 'Player Trading'),
(2, 'Market Transaction'),
(3, 'GM Cash Transfer'),
(4, 'ATM Withdraw'),
(5, 'ATM Deposit'),
(6, 'Backward Compatible'),
(7, 'Mission Reward'),
(8, 'Clone Activation'),
(9, 'Inheritance'),
(10, 'Player Donation'),
(11, 'Corporation Payment'),
(12, 'Docking Fee'),
(13, 'Office Rental Fee'),
(14, 'Factory Slot Rental Fee'),
(15, 'Repair Bill'),
(16, 'Bounty'),
(17, 'Bounty Prize'),
(18, 'Agents_temporary'),
(19, 'Insurance'),
(20, 'Mission Expiration'),
(21, 'Mission Completion'),
(22, 'Shares'),
(23, 'Courier Mission Escrow'),
(24, 'Mission Cost'),
(25, 'Agent Miscellaneous'),
(26, 'LP Store'),
(27, 'Agent Location Services'),
(28, 'Agent Donation'),
(29, 'Agent Security Services'),
(30, 'Agent Mission Collateral Paid'),
(31, 'Agent Mission Collateral Refunded'),
(32, 'Agents_preward'),
(33, 'Agent Mission Reward'),
(34, 'Agent Mission Time Bonus Reward'),
(35, 'CSPA'),
(36, 'CSPAOfflineRefund'),
(37, 'Corporation Account Withdrawal'),
(38, 'Corporation Dividend Payment'),
(39, 'Corporation Registration Fee'),
(40, 'Corporation Logo Change Cost'),
(41, 'Release Of Impounded Property'),
(42, 'Market Escrow'),
(43, 'Agent Services Rendered'),
(44, 'Market Fine Paid'),
(45, 'Corporation Liquidation'),
(46, 'Brokers Fee'),
(47, 'Corporation Bulk Payment'),
(48, 'Alliance Registration Fee'),
(49, 'War Fee'),
(50, 'Alliance Maintainance Fee'),
(51, 'Contraband Fine'),
(52, 'Clone Transfer'),
(53, 'Acceleration Gate Fee'),
(54, 'Transaction Tax'),
(55, 'Jump Clone Installation Fee'),
(56, 'Manufacturing'),
(57, 'Researching Technology'),
(58, 'Researching Time Productivity'),
(59, 'Researching Material Productivity'),
(60, 'Copying'),
(61, 'Duplicating'),
(62, 'Reverse Engineering'),
(63, 'Contract Auction Bid'),
(64, 'Contract Auction Bid Refund'),
(65, 'Contract Collateral'),
(66, 'Contract Reward Refund'),
(67, 'Contract Auction Sold'),
(68, 'Contract Reward'),
(69, 'Contract Collateral Refund'),
(70, 'Contract Collateral Payout'),
(71, 'Contract Price'),
(72, 'Contract Brokers Fee'),
(73, 'Contract Sales Tax'),
(74, 'Contract Deposit'),
(75, 'Contract Deposit Sales Tax'),
(76, 'Secure EVE Time Code Exchange'),
(77, 'Contract Auction Bid (corp)'),
(78, 'Contract Collateral Deposited (corp)'),
(79, 'Contract Price Payment (corp)'),
(80, 'Contract Brokers Fee (corp)'),
(81, 'Contract Deposit (corp)'),
(82, 'Contract Deposit Refund'),
(83, 'Contract Reward Deposited'),
(84, 'Contract Reward Deposited (corp)'),
(85, 'Bounty Prizes'),
(86, 'Advertisement Listing Fee'),
(87, 'Medal Creation'),
(88, 'Medal Issued'),
(89, 'Betting'),
(90, 'DNA Modification Fee'),
(91, 'Sovereignty bill'),
(92, 'Bounty Prize Corporation Tax'),
(93, 'Agent Mission Reward Corporation Tax'),
(94, 'Agent Mission Time Bonus Reward Corporation Tax'),
(95, 'Upkeep adjustment fee'),
(96, 'Planetary Import Tax'),
(97, 'Planetary Export Tax'),
(98, 'Planetary Construction'),
(99, 'Corporate Reward Payout'),
(101, 'Bounty Surcharge'),
(102, 'Contract Reversal'),
(103, 'Corporate Reward Tax'),
(106, 'Store Purchase'),
(107, 'Store Purchase Refund'),
(108, 'PLEX sold for Aurum'),
(109, 'Lottery Give Away'),
(111, 'Aurum Token exchanged for Aur'),
(112, 'Datacore Fee'),
(113, 'War Surrender Fee'),
(114, 'War Ally Contract'),
(115, 'Bounty Reimbursement'),
(116, 'Kill Right'),
(117, 'Fee for processing one or more security tags'),
(10001, 'Modify ISK'),
(10002, 'Primary Marketplace Purchase'),
(10003, 'Battle Reward'),
(10004, 'New Character Starting Funds'),
(10005, 'Corporation Account Withdrawal'),
(10006, 'Corporation Account Deposit'),
(10007, 'Battle WP Win Reward'),
(10008, 'Battle WP Loss Reward'),
(10009, 'Battle Win Reward'),
(10010, 'Battle Loss Reward'),
(10011, 'Unknown'),
(10012, 'District Contract Deposit'),
(10013, 'District Contract Deposit Refund'),
(10014, 'District Contract Collateral'),
(10015, 'District Contract Collateral Refund'),
(10016, 'District Contract Reward'),
(10017, 'District Clone Transportation'),
(10018, 'District Clone Transportation Refund'),
(10019, 'District Infrastructure'),
(10020, 'District Clone Sales'),
(10021, 'District Clone Purchase'),
(10022, 'Biomass Reward'),
(10023, 'Unknown'),
(10024, 'Unknown'),
(10025, 'Unknown'),
(11001, 'Modify AUR'),
(11002, 'Respec payment'),
(11003, 'Unknown'),
(11004, 'Unknown'),
(11005, 'Unknown');