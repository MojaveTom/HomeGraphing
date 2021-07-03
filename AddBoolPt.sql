DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_Pump ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        /*
        CREATE TABLE IF NOT EXISTS `demay_farm`.`BoolTableTemplate`
        (
            Id BIGINT AUTO_INCREMENT PRIMARY KEY, -- primary key column
            Time DATETIME(6),
            value BOOLEAN,
            duration FLOAT
        );
        */
        SET @newT = newTime;
        SET @newV = newval;

        -- CREATE TABLE IF NOT EXISTS `demay_farm`.`pump_data` LIKE `demay_farm`.`BoolTableTemplate`;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`pump_data`;
        IF @rowCount > 1 THEN
            UPDATE `demay_farm`.`pump_data` SET Time = @newT WHERE Id = @theId;
            IF (@prevVal = 0) and (newval = 1) THEN
                INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, @newT, @newV, 0);
            ELSEIF (@prevVal = 1) and (newval = 1) THEN
                SET @dur = UNIX_TIMESTAMP(newTime) - UNIX_TIMESTAMP(@prevTm1);
                UPDATE `demay_farm`.`pump_data` SET duration = @dur WHERE Id >= @iDm1;
            ELSEIF (@prevVal = 1) and (newval = 0) THEN
                SET @dur = UNIX_TIMESTAMP(newTime) - UNIX_TIMESTAMP(@prevTm1);
                UPDATE `demay_farm`.`pump_data` SET duration = @dur WHERE Id >= @iDm1;
                INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, @newT, @newV, 0);
            END IF;
        ELSE
            -- select "Inserting", "first rows.";
            INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

/*

        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:30:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:31:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:32:00.123456', 1); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:33:00.123456', 1); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:34:00.123456', 1); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:35:00.123456', 1); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:36:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:37:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:38:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:39:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:45:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:46:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:47:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:48:00.123456', 0); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:52:00.123456', 1); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:53:00.123456', 1); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:54:00.123456', 1); SELECT * FROM pump_data;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
CALL add_pt_to_Pump('2021-06-04 10:55:00.123456', 1); SELECT * FROM pump_data;
--*/
