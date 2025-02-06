CREATE DATABASE huiwang_material_shop;

USE huiwang_material_shop;

CREATE TABLE account (
                         open_id VARCHAR(32) PRIMARY KEY COMMENT '微信openid',
                         union_id VARCHAR(64) COMMENT '微信unionID',
                         username VARCHAR(64) COMMENT '微信昵称或者后台名称',
                         password VARCHAR(32),
                         avatar_url VARCHAR(255) COMMENT '头像URL',
                         mobile VARCHAR(15) COMMENT '手机号',
                         balance DECIMAL(10,2) DEFAULT 0 COMMENT '账户余额',
                         create_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_address (
                              address_id INT AUTO_INCREMENT PRIMARY KEY,
                              user_id VARCHAR(32),
                              consignee VARCHAR(32) COMMENT '收货人',
                              mobile VARCHAR(15),
                              province VARCHAR(20),
                              city VARCHAR(20),
                              district VARCHAR(20),
                              detail VARCHAR(255),
                              is_default BOOLEAN DEFAULT false,
                              FOREIGN KEY (user_id) REFERENCES account(open_id)
);

CREATE TABLE `user_role` (
                             `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
                             `name` VARCHAR(50) NOT NULL UNIQUE,
                             `description` VARCHAR(255),
                             `created_at` TIMESTAMP NOT NULL default CURRENT_TIMESTAMP,
                             `updated_at` TIMESTAMP NOT NULL default CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE `user_role_mapping` (
                                     `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
                                     `user_id` VARCHAR(32) NOT NULL,
                                     `role_id` BIGINT NOT NULL,
                                     `created_at` TIMESTAMP NOT NULL default CURRENT_TIMESTAMP,
                                     FOREIGN KEY (`user_id`) REFERENCES `account`(`open_id`),
                                     FOREIGN KEY (`role_id`) REFERENCES `user_role`(`id`)
);

CREATE INDEX idx_user_id ON user_role_mapping(user_id);
CREATE INDEX idx_role_id ON user_role_mapping(role_id);

-- 商品分类表
CREATE TABLE product_category (
                                  category_id INT PRIMARY KEY AUTO_INCREMENT,
                                  name VARCHAR(50) NOT NULL,
                                  parent_id INT NULL COMMENT '父级分类ID',
                                  sort_order INT DEFAULT 0,
                                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                  FOREIGN KEY (parent_id) REFERENCES product_category(category_id)
);

-- 商品表
CREATE TABLE product (
                         product_id INT PRIMARY KEY AUTO_INCREMENT,
                         category_id INT NOT NULL,
                         name VARCHAR(100) NOT NULL,
                         description TEXT,
                         price DECIMAL(10,2) NOT NULL,
                         stock INT NOT NULL DEFAULT 0,
                         status TINYINT(1) DEFAULT 1 COMMENT '1-上架 0-下架',
                         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                         updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                         FOREIGN KEY (category_id) REFERENCES product_category(category_id)
);

CREATE TABLE product_sku (
                             sku_id INT PRIMARY KEY AUTO_INCREMENT,
                             product_id INT NOT NULL,
                             attributes JSON COMMENT 'SKU属性（如颜色、尺寸）',
                             price DECIMAL(10,2) NOT NULL,
                             stock INT NOT NULL DEFAULT 0,
                             FOREIGN KEY (product_id) REFERENCES product(product_id)
);

CREATE TABLE orders (
                        order_id VARCHAR(32) PRIMARY KEY COMMENT '订单号',
                        user_id VARCHAR(32),
                        total_amount DECIMAL(10,2),
                        payment_amount DECIMAL(10,2),
                        status TINYINT DEFAULT 0 COMMENT '0-待支付 1-已支付 2-已发货 3-已完成 4-已关闭',
                        payment_time TIMESTAMP,
                        address_id INT,
                        express_no VARCHAR(50) COMMENT '物流单号',
                        points_amount DECIMAL(10,2) DEFAULT 0 COMMENT '积分抵扣金额',
                        coupon_id INT COMMENT '使用的优惠券ID',
                        create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES account(open_id),
                        FOREIGN KEY (address_id) REFERENCES user_address(address_id)
);

CREATE TABLE order_items (
                             item_id INT AUTO_INCREMENT PRIMARY KEY,
                             order_id VARCHAR(32),
                             product_id INT,
                             sku_id INT,
                             quantity INT,
                             unit_price DECIMAL(10,2),
                             snapshot JSON COMMENT '商品快照信息',
                             FOREIGN KEY (order_id) REFERENCES orders(order_id),
                             FOREIGN KEY (sku_id) REFERENCES product_sku(sku_id)
);

-- 优惠券表
CREATE TABLE coupon (
                        coupon_id INT PRIMARY KEY AUTO_INCREMENT,
                        code VARCHAR(20) UNIQUE NOT NULL,
                        name VARCHAR(50) NOT NULL,
                        description TEXT,
                        discount_type ENUM('FIXED','PERCENT','FULL_REDUCTION') NOT NULL COMMENT '固定金额/百分比/满减',
                        discount_value DECIMAL(10,2) NOT NULL,
                        min_amount DECIMAL(10,2) DEFAULT 0 COMMENT '最低消费金额',
                        max_discount DECIMAL(10,2) COMMENT '最大抵扣金额',
                        start_time TIMESTAMP NOT NULL,
                        end_time TIMESTAMP NOT NULL,
                        total_quantity INT NOT NULL COMMENT '发放总量',
                        remaining_quantity INT UNSIGNED NOT NULL,
                        limit_per_user INT DEFAULT 1 COMMENT '每人限领数量',
                        applicable_type ENUM('ALL','CATEGORY','PRODUCT') DEFAULT 'ALL'
);

-- 用户优惠券表
CREATE TABLE user_coupon (
                             user_coupon_id BIGINT PRIMARY KEY AUTO_INCREMENT,
                             user_id VARCHAR(32) NOT NULL,
                             coupon_id INT NOT NULL,
                             status ENUM('UNUSED','USED','EXPIRED') DEFAULT 'UNUSED',
                             used_time TIMESTAMP,
                             order_id VARCHAR(32) COMMENT '使用的订单ID',
                             created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                             FOREIGN KEY (coupon_id) REFERENCES coupon(coupon_id)
);

-- 优惠券适用商品分类
CREATE TABLE coupon_applicable_category (
                                            coupon_id INT NOT NULL,
                                            category_id INT NOT NULL,
                                            PRIMARY KEY (coupon_id, category_id),
                                            FOREIGN KEY (coupon_id) REFERENCES coupon(coupon_id),
                                            FOREIGN KEY (category_id) REFERENCES product_category(category_id)
);

-- 优惠券适用商品
CREATE TABLE coupon_applicable_product (
                                           coupon_id INT NOT NULL,
                                           product_id INT NOT NULL,
                                           PRIMARY KEY (coupon_id, product_id),
                                           FOREIGN KEY (coupon_id) REFERENCES coupon(coupon_id),
                                           FOREIGN KEY (product_id) REFERENCES product(product_id)
);

-- 积分使用规则表
CREATE TABLE points_usage_rule (
                                   rule_id INT PRIMARY KEY AUTO_INCREMENT,
                                   rule_type ENUM('CASH','COUPON') NOT NULL,
                                   points INT NOT NULL COMMENT '所需积分',
                                   cash_value DECIMAL(10,2) COMMENT '可抵扣金额',
                                   coupon_id INT COMMENT '兑换的优惠券ID',
                                   validity_days INT COMMENT '有效期天数',
                                   status TINYINT(1) DEFAULT 1
);

-- 积分明细表
CREATE TABLE points_detail (
                               detail_id BIGINT PRIMARY KEY AUTO_INCREMENT,
                               user_id VARCHAR(32) NOT NULL,
                               points INT NOT NULL,
                               type ENUM('INCOME','EXPENSE') NOT NULL COMMENT '积分获取/消耗',
                               source_type VARCHAR(20) COMMENT '来源类型：order_payment/coupon_exchange',
                               source_id BIGINT COMMENT '关联ID（如订单ID）',
                               expired_time DATETIME COMMENT '过期时间',
                               created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 新增打印任务表
CREATE TABLE print_tasks (
                             task_id BIGINT PRIMARY KEY COMMENT '雪花算法生成',
                             order_id VARCHAR(32) NOT NULL,
                             print_type TINYINT NOT NULL COMMENT '1-发货单 2-物流面单 3-发票',
                             content LONGTEXT COMMENT '打印内容/模板数据',
                             create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                             FOREIGN KEY (order_id) REFERENCES orders(order_id),
                             INDEX idx_order_id(order_id)
);