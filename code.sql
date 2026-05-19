create database AGROCULTURE;
-- Step 1: Initialize Database
CREATE DATABASE IF NOT EXISTS AgroCulture;
USE AgroCulture;

-- Step 2: Create FARMER Table
-- FD: Farmer_ID -> Name, Username, Email, Mobile, Address, Rating
CREATE TABLE Farmer (
    Farmer_ID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Username VARCHAR(50) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Mobile VARCHAR(15) NOT NULL,
    Address TEXT NOT NULL,
    Rating DECIMAL(3,2) DEFAULT 5.00
);

-- Step 3: Create BUYER Table
-- FD: Buyer_ID -> Name, Username, Email, Mobile, Address
CREATE TABLE Buyer (
    Buyer_ID INT PRIMARY KEY AUTO_INCREMENT,
    Name VARCHAR(100) NOT NULL,
    Username VARCHAR(50) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Mobile VARCHAR(15) NOT NULL,
    Address TEXT NOT NULL
);

-- Step 4: Create PRODUCT Table
-- FD: Product_ID -> Product_Name, Category, Price, Description, Farmer_ID
CREATE TABLE Product (
    Product_ID INT PRIMARY KEY AUTO_INCREMENT,
    Product_Name VARCHAR(100) NOT NULL,
    Category VARCHAR(50),
    Price DECIMAL(10,2) NOT NULL,
    Description TEXT,
    Farmer_ID INT,
    FOREIGN KEY (Farmer_ID) REFERENCES Farmer(Farmer_ID) ON DELETE CASCADE
);

-- Step 5: Create TRANSACTION Table
-- FD: Transaction_ID -> Buyer_ID, Product_ID, Quantity, City, Pincode
CREATE TABLE Transaction (
    Transaction_ID INT PRIMARY KEY AUTO_INCREMENT,
    Buyer_ID INT,
    Product_ID INT,
    Quantity INT NOT NULL,
    City VARCHAR(100),
    Pincode VARCHAR(10),
    FOREIGN KEY (Buyer_ID) REFERENCES Buyer(Buyer_ID),
    FOREIGN KEY (Product_ID) REFERENCES Product(Product_ID)
);

-- Step 6: Create REVIEW Table
-- FD: Review_ID -> Rating, Comment, Product_ID
CREATE TABLE Review (
    Review_ID INT PRIMARY KEY AUTO_INCREMENT,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    Comment TEXT,
    Product_ID INT,
    FOREIGN KEY (Product_ID) REFERENCES Product(Product_ID) ON DELETE CASCADE
);

-- Step 7: Create BLOG Table
-- FD: Blog_ID -> Blog_User, Title, Content, Timestamp
CREATE TABLE Blog (
    Blog_ID INT PRIMARY KEY AUTO_INCREMENT,
    Blog_User VARCHAR(100),
    Title VARCHAR(200),
    Content TEXT,
    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
DELIMITER //
CREATE TRIGGER validate_transaction_qty
BEFORE INSERT ON Transaction
FOR EACH ROW
BEGIN
    IF NEW.Quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be a positive integer.';
    END IF;
END //
DELIMITER ;
DELIMITER //
CREATE PROCEDURE ProcessNewSale(
    IN p_Buyer_ID INT, 
    IN p_Product_ID INT, 
    IN p_Qty INT, 
    IN p_City VARCHAR(100), 
    IN p_Pin VARCHAR(10)
)
BEGIN
    INSERT INTO Transaction (Buyer_ID, Product_ID, Quantity, City, Pincode) 
    VALUES (p_Buyer_ID, p_Product_ID, p_Qty, p_City, p_Pin);
END //
DELIMITER ;
DELIMITER //
CREATE FUNCTION GetOrderTotal(p_ProdID INT, p_Qty INT) 
RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    DECLARE v_Price DECIMAL(10,2);
    SELECT Price INTO v_Price FROM Product WHERE Product_ID = p_ProdID;
    RETURN (v_Price * p_Qty);
END //
DELIMITER ;
DELIMITER //
CREATE PROCEDURE FetchCommunityBlogs()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE b_title VARCHAR(200);
    DECLARE blog_cursor CURSOR FOR SELECT Title FROM Blog;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN blog_cursor;
    blog_loop: LOOP
        FETCH blog_cursor INTO b_title;
        IF done THEN
            LEAVE blog_loop;
        END IF;
        SELECT b_title AS 'Current Blog Post';
    END LOOP;
    CLOSE blog_cursor;
END //
DELIMITER ;
show tables;

describe product;
DELIMITER //
CREATE TRIGGER before_product_insert
BEFORE INSERT ON Product
FOR EACH ROW
BEGIN
    -- Ensure price is positive
    IF NEW.Price <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Price must be greater than zero.';
    END IF;
    
    -- Business logic check
    IF NEW.Price < 5.00 THEN
        -- This could also log to an 'Audit' table if you create one
        SET NEW.Description = CONCAT('(Budget Item) ', NEW.Description);
    END IF;
END //
DELIMITER ;
DELIMITER //
CREATE PROCEDURE GetBuyerSpendingReport(IN p_BuyerID INT, OUT p_TotalSpent DECIMAL(15,2))
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_Qty INT;
    DECLARE v_ProdID INT;
    DECLARE v_ItemTotal DECIMAL(10,2);
    
    -- Declare Cursor to fetch buyer's transactions
    DECLARE trans_cursor CURSOR FOR 
        SELECT Quantity, Product_ID FROM Transaction WHERE Buyer_ID = p_BuyerID;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    SET p_TotalSpent = 0;
    
    OPEN trans_cursor;
    
    read_loop: LOOP
        FETCH trans_cursor INTO v_Qty, v_ProdID;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Use the previously created Function to get order total
        SET v_ItemTotal = GetOrderTotal(v_ProdID, v_Qty);
        SET p_TotalSpent = p_TotalSpent + v_ItemTotal;
    END LOOP;
    
    CLOSE trans_cursor;
END //
DELIMITER ;
DELIMITER //
CREATE FUNCTION CalculateFarmerAvgRating(p_FarmerID INT) 
RETURNS DECIMAL(3,2)
DETERMINISTIC
BEGIN
    DECLARE v_Avg DECIMAL(3,2);
    
    SELECT AVG(r.Rating) INTO v_Avg
    FROM Review r
    JOIN Product p ON r.Product_ID = p.Product_ID
    WHERE p.Farmer_ID = p_FarmerID;
    
    -- If no reviews exist, return default 5.00
    RETURN IFNULL(v_Avg, 5.00);
END //
DELIMITER ;
SELECT 
    Category, 
    COUNT(Product_ID) AS Total_Products, 
    SUM(Quantity) AS Total_Units_Sold,
    ROUND(AVG(Price), 2) AS Avg_Category_Price
FROM Product
LEFT JOIN Transaction USING (Product_ID)
GROUP BY Category
HAVING Total_Units_Sold > 0
ORDER BY Total_Units_Sold DESC;
-- This should fail and show your custom error message
INSERT INTO Product (Product_Name, Category, Price, Description, Farmer_ID) 
VALUES ('Error Wheat', 'Grains', -5.00, 'Invalid price test', 1);
-- 1. Call the procedure for Buyer #1
CALL GetBuyerSpendingReport(1, @total);

-- 2. View the result stored in the variable
SELECT @total AS 'Lifetime Spending';
-- Get a list of all farmers and their dynamically calculated average ratings
SELECT Name, CalculateFarmerAvgRating(Farmer_ID) AS Current_Rating 
FROM Farmer;
INSERT INTO Farmer (Name, Username, Password, Email, Mobile, Address, Rating) VALUES
('Ramesh Kumar', 'ramesh_k', 'pass123', 'ramesh@agro.com', '9876543210', 'Patiala, Punjab', 4.5),
('Sunita Devi', 'sunita_d', 'farm456', 'sunita@agro.com', '9876543211', 'Ludhiana, Punjab', 4.8),
('Amit Singh', 'amit_s', 'agri789', 'amit@agro.com', '9876543212', 'Amritsar, Punjab', 4.2),
('Priya Sharma', 'priya_s', 'sharma12', 'priya@agro.com', '9876543213', 'Bathinda, Punjab', 4.6),
('Gurpreet Singh', 'gur_s', 'pind321', 'gurpreet@agro.com', '9876543214', 'Jalandhar, Punjab', 4.9),
('Anita Rani', 'anita_r', 'rani88', 'anita@agro.com', '9876543215', 'Moga, Punjab', 4.0),
('Rajesh Gupta', 'raj_g', 'gupta99', 'rajesh@agro.com', '9876543216', 'Karnal, Haryana', 4.3),
('Sandeep Kaur', 'sandy_k', 'kaur55', 'sandeep@agro.com', '9876543217', 'Sirsa, Haryana', 4.7),
('Mohan Lal', 'mohan_l', 'lal10', 'mohan@agro.com', '9876543218', 'Hisar, Haryana', 4.1),
('Vikram Jeet', 'vikram_j', 'jeet77', 'vikram@agro.com', '9876543219', 'Panipat, Haryana', 4.4);
select * from farmer;
INSERT INTO Buyer (Name, Username, Password, Email, Mobile, Address) VALUES
('Vijay Vohra', 'vijay_v', 'buyer1', 'vijay@gmail.com', '8876543210', 'Chandigarh'),
('Megha Jain', 'megha_j', 'buyer2', 'megha@gmail.com', '8876543211', 'Delhi'),
('Suresh Raina', 'suresh_r', 'buyer3', 'suresh@gmail.com', '8876543212', 'Noida'),
('Kavita Singh', 'kavita_s', 'buyer4', 'kavita@gmail.com', '8876543213', 'Gurgaon'),
('Rahul Mehra', 'rahul_m', 'buyer5', 'rahul@gmail.com', '8876543214', 'Shimla'),
('Deepak Cho', 'deepak_c', 'buyer6', 'deepak@gmail.com', '8876543215', 'Mohali'),
('Pooja Bhatia', 'pooja_b', 'buyer7', 'pooja@gmail.com', '8876543216', 'Panchkula'),
('Arjun Kapoor', 'arjun_k', 'buyer8', 'arjun@gmail.com', '8876543217', 'Ambala'),
('Sneha Roy', 'sneha_r', 'buyer9', 'sneha@gmail.com', '8876543218', 'Lucknow'),
('Varun Dhawan', 'varun_d', 'buyer10', 'varun@gmail.com', '8876543219', 'Jaipur');
select * from Buyer;
INSERT INTO Product (Product_Name, Category, Price, Description, Farmer_ID) VALUES
('Basmati Rice', 'Grains', 95.00, 'Premium long grain rice', 1),
('Organic Wheat', 'Grains', 40.00, 'Chemical-free wheat flour', 2),
('Desi Ghee', 'Dairy', 650.00, 'Pure buffalo milk ghee', 3),
('Fresh Carrots', 'Vegetables', 30.00, 'Farm fresh red carrots', 4),
('Mustard Oil', 'Oils', 180.00, 'Cold pressed mustard oil', 5),
('Green Moong Dal', 'Pulses', 120.00, 'Organic green gram', 6),
('Honey', 'Organic', 450.00, 'Pure forest honey', 7),
('Turmeric Powder', 'Spices', 250.00, 'High curcumin turmeric', 8),
('Red Onions', 'Vegetables', 35.00, 'Freshly harvested onions', 9),
('Apples', 'Fruits', 150.00, 'Kinnaur valley apples', 10);
select * from Product;
INSERT INTO Transaction (Buyer_ID, Product_ID, Quantity, City, Pincode) VALUES
(1, 1, 5, 'Chandigarh', '160001'),
(2, 2, 10, 'Delhi', '110001'),
(3, 3, 2, 'Noida', '201301'),
(4, 4, 15, 'Gurgaon', '122001'),
(5, 5, 4, 'Shimla', '171001'),
(6, 6, 8, 'Mohali', '160062'),
(7, 7, 1, 'Panchkula', '134109'),
(8, 8, 3, 'Ambala', '133001'),
(9, 9, 20, 'Lucknow', '226001'),
(10, 10, 5, 'Jaipur', '302001');
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Transaction;
TRUNCATE TABLE Review;
TRUNCATE TABLE Product;
TRUNCATE TABLE Buyer;
TRUNCATE TABLE Farmer;
SET FOREIGN_KEY_CHECKS = 1;
INSERT INTO Farmer (Name, Username, Password, Email, Mobile, Address) VALUES
('Ramesh Kumar', 'ramesh_k', 'pass123', 'ramesh@agro.com', '9876543210', 'Punjab'),
('Sunita Devi', 'sunita_d', 'farm456', 'sunita@agro.com', '9876543211', 'Punjab');

INSERT INTO Buyer (Name, Username, Password, Email, Mobile, Address) VALUES
('Vijay Vohra', 'vijay_v', 'buyer1', 'vijay@gmail.com', '8876543210', 'Chandigarh'),
('Megha Jain', 'megha_j', 'buyer2', 'megha@gmail.com', '8876543211', 'Delhi');
INSERT INTO Product (Product_Name, Category, Price, Description, Farmer_ID) VALUES
('Basmati Rice', 'Grains', 95.00, 'Premium long grain rice', 1),
('Organic Wheat', 'Grains', 40.00, 'Chemical-free wheat flour', 2);
INSERT INTO Transaction (Buyer_ID, Product_ID, Quantity, City, Pincode) VALUES
(1, 1, 5, 'Chandigarh', '160001'),
(2, 2, 10, 'Delhi', '110001');
SELECT T.Transaction_ID, B.Name AS Buyer, P.Product_Name 
FROM Transaction T
JOIN Buyer B ON T.Buyer_ID = B.Buyer_ID
JOIN Product P ON T.Product_ID = P.Product_ID;
select * from product;
show tables;
select * from product;
