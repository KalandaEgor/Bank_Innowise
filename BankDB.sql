CREATE DATABASE BankDB

CREATE TABLE Bank
(
	id_bank		  INTEGER  PRIMARY KEY  IDENTITY(1,1)  NOT NULL,
	BankName	  VARCHAR(50)  NOT NULL 
)

CREATE TABLE Statuses
(
	id_status	  INTEGER  PRIMARY KEY  IDENTITY(1,1)  NOT NULL ,
	StatusName	  VARCHAR(20)  NOT NULL 
);

CREATE TABLE Account
(
	id_account	    INTEGER  PRIMARY KEY  IDENTITY(1,1)  NOT NULL ,
	ClientName	    VARCHAR(50)  NOT NULL ,
	id_bank			INTEGER  NOT NULL  FOREIGN KEY (id_bank)  REFERENCES Bank (id_bank),
	id_status		INTEGER  NOT NULL  FOREIGN KEY (id_status)  REFERENCES Statuses (id_status),
	AmountAccount   MONEY  NOT NULL 
)

CREATE TABLE Affiliates
(
	id_affiliate	  INTEGER  PRIMARY KEY  IDENTITY(1,1)  NOT NULL ,
	AffiliateName	  VARCHAR(50)  NOT NULL ,
	AffiliateCity	  VARCHAR(20)  NOT NULL ,
	id_bank			  INTEGER  NOT NULL  FOREIGN KEY (id_bank)  REFERENCES Bank (id_bank) 
);

CREATE TABLE Cards
(
	id_card		  INTEGER  PRIMARY KEY  IDENTITY(1,1)  NOT NULL ,
	id_account	  INTEGER  NOT NULL  FOREIGN KEY (id_account)  REFERENCES Account (id_account),
	CardNumber	  VARCHAR(19)  NOT NULL ,
	AmountCard	  MONEY  NOT NULL 
);


INSERT INTO Bank (BankName) VALUES 
    ('ООО "Приорбанк"'), 
    ('ОАО "Беларусбанк"'),
    ('ОАО "Альфа-Банк"'),
    ('ОАО "Белинвестбанк"'),
    ('ООО "Сбер Банк"');

INSERT INTO Statuses (StatusName) VALUES 
    ('Инвалид'), 
    ('Пенсионер'),
    ('Ветеран'),
    ('Работоспособный'),
    ('Ребёнок');

INSERT INTO Affiliates (AffiliateName, AffiliateCity, id_bank) VALUES 
    ('Филиал ООО "Приорбанк" №1', 'Полоцк', 1), 
    ('Филиал ОАО "Беларусбанк"', 'Минск', 2),
    ('Филиал ООО "Приорбанк" №2', 'Полоцк', 1),
    ('Филиал ОАО "Альфа-Банк"', 'Витебск', 3),
    ('Филиал ООО "Сбер Банк"', 'Гродно', 5);

INSERT INTO Account (ClientName, id_bank, id_status, AmountAccount) VALUES 
    ('Степанов Николай Валерьевич', 1, 4, 560), 
    ('Иванов Владимир Иванович', 3, 5, 320),
    ('Смирнова Анна Дмитриевна', 2, 3, 745),
    ('Петров Константин Витальевич', 4, 3, 270),
    ('Григорьева Тамара Михайловна', 5, 1, 460);

INSERT INTO Cards (id_account, CardNumber, AmountCard) VALUES 
    (1, '4567 0987 2643 6548', 450), 
    (2, '3453 5673 6554 8724', 120),
    (4, '5975 6445 5473 8748', 100),
    (2, '5747 0898 2743 2456', 150),
    (5, '9674 0876 2345 6836', 460);


SELECT BankName
FROM Bank
	JOIN Affiliates 
    ON Bank.id_bank = Affiliates.id_bank
WHERE AffiliateCity = 'Полоцк'


SELECT CardNumber, ClientName, AmountCard, BankName
FROM Cards
	JOIN Account 
    ON Account.id_account = Cards.id_account
	JOIN Bank 
    ON Account.id_bank = Bank.id_bank


SELECT Account.ClientName, Account.AmountAccount -
(
	SELECT SUM(AmountCard)
	FROM Cards
	WHERE Cards.id_account = Account.id_account
) 
AS [Difference]
FROM Account
WHERE Account.AmountAccount != 
(
	SELECT SUM(AmountCard)
	FROM Cards
	WHERE Cards.id_account = Account.id_account
)


SELECT StatusName, COUNT(Account.id_status) AS [Card quantity]
FROM Statuses, Account
WHERE Account.id_status = Statuses.id_status
GROUP BY StatusName


SELECT StatusName,
(
	SELECT COUNT(Account.id_account)
	FROM Account
	WHERE Account.id_status = Statuses.id_status
)
AS [Card quantity] 
FROM Statuses


CREATE PROCEDURE AddTen
	@id_status INTEGER
AS
BEGIN TRY
	UPDATE Account
	SET AmountAccount += 10
	WHERE id_status = @id_status; 
END TRY
BEGIN CATCH
	PRINT 'Error: ' + error_message()
END CATCH;
GO

SELECT *
FROM Account

EXEC AddTen 1

SELECT *
FROM Account


SELECT
CASE
WHEN
(
	SELECT SUM(AmountCard)
	FROM Cards
	WHERE Cards.id_account = Account.id_account
) != 0
THEN 
AmountAccount - 
(
	SELECT SUM(AmountCard)
	FROM Cards
	WHERE Cards.id_account = Account.id_account
)
ELSE AmountAccount
END AS Free
FROM Account


CREATE PROCEDURE CardTransaction
	@id_account INTEGER,
	@id_card INTEGER,
	@sum MONEY
AS
BEGIN TRY
   DECLARE @Free MONEY
   SELECT @Free =
	CASE
	WHEN
	(
		SELECT SUM(AmountCard)
		FROM Cards
		WHERE Cards.id_account = @id_account
	) != 0
	THEN 
	AmountAccount - 
	(
		SELECT SUM(AmountCard)
		FROM Cards
		WHERE Cards.id_account = @id_account
	)
	ELSE AmountAccount
	END 
	FROM Account
	WHERE id_account = @id_account
    BEGIN TRANSACTION
	   IF @Free > @sum
		UPDATE Cards
		SET AmountCard += @sum
		WHERE id_card = @id_card
			AND id_account = @id_account
END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION
	SELECT ERROR_NUMBER() AS [Номер ошибки],
           ERROR_MESSAGE() AS [Описание ошибки]
	RETURN
END CATCH
COMMIT TRANSACTION
GO


SELECT *
FROM Cards

EXEC CardTransaction 1,1,10

SELECT *
FROM Cards


CREATE TRIGGER BalanceTrigger 
ON Account
FOR UPDATE
AS
BEGIN
	DECLARE @NewAmount MONEY
	SELECT @NewAmount = AmountAccount
	FROM INSERTED 

	IF @NewAmount < 
	(
		SELECT SUM(AmountCard)
		FROM Cards
			JOIN INSERTED I
			ON Cards.id_account = I.id_account
	)
	BEGIN
		ROLLBACK TRANSACTION
		RAISERROR('Changes column name not allowed', 16, 1);
	END
	ELSE
	BEGIN
		PRINT 'Balance changed'
	END
END


ALTER TRIGGER BalanceCardsTrigger 
ON Cards
FOR UPDATE
AS
BEGIN
	DECLARE @AmountAccount MONEY
	SELECT @AmountAccount = AmountAccount
	FROM Account
		JOIN INSERTED I
		ON Account.id_account = I.id_account
	IF @AmountAccount < 
	(
		SELECT SUM(Cards.AmountCard)
		FROM Cards
			JOIN INSERTED I
			ON Cards.id_account = I.id_account
	)
	BEGIN
		ROLLBACK TRANSACTION
		RAISERROR('Changes column name not allowed', 16, 1);
	END
	ELSE
	BEGIN
		PRINT 'Balance changed'
	END
END

