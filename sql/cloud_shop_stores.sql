CREATE TABLE IF NOT EXISTS `cloud_shop_stores` (
  `shop_key` VARCHAR(64) NOT NULL,
  `data_json` LONGTEXT NOT NULL,
  PRIMARY KEY (`shop_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
