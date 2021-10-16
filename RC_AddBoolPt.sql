/*
 *  Call this procedure each time a new row of pressure booster pump data is added to the
 *  mqttmessages table.  It updates the pump_data table with extracted information.
 *  
 *  The idea is to have two rows in the table for each change in the state of the pump,
 *  the first having the time of the change, and the second having the time of the next
 *  change, and both having the duration of the state.  To make plotting the durations
 *  make a "square wave" with the height being the duration of each state.
 *
 *  Args:
 *    newTime: DATETIME(6)  The timestamp for the newly inserted data point.
 *    newval:  BOOLEAN      The value of the state of the pump running (true if running).
 *
 *  Session Vars created/used inside:
 *    @theId      The id of the last row in the pump_data table.
 *    @prevVal    The state of the pump in the last row in the pump_data table.
 *    @iDm1       The id of the second to last row in the pump_data table.
 *    @prevTm1    The time of the second to last row in the pump_data table.
 *
 *  Unused session Vars used inside:
 *    @iD         = @theId
 *    @prevT      The time of the last row in the pump_data table.
 *                  Gets updated every time a new point is added to mqttmessages.
 *    @prevValm1  The state of the pump in the second to last row in the pump_data table.
 *
 *  The duration column in the pump_data table is updated to reflect the duration that
 *  the pump has been in the same state.  When the pump state changes, two rows are added
 *  to the table with the time of the second advanced by one microsecond (to keep the rows
 *  in the same order whether sorted by time or id).  The duration of both added rows is
 *  zero, but will be updated when the next pump data comes in.
 *
 *  See comments below for table creation.
 */

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_Pump ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`pump_data`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`pump_data` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`pump_data` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$
DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_PressurePump ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`pressure_pump`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pressure_pump`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pressure_pump` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pressure_pump` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`pressure_pump` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`pressure_pump` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`pressure_pump` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`pressure_pump` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`pressure_pump` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_SubmersiblePump ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`submersible_pump`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`submersible_pump`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`submersible_pump` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`submersible_pump` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`submersible_pump` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`submersible_pump` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`submersible_pump` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`submersible_pump` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`submersible_pump` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_kitchen_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`kitchen_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`kitchen_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`kitchen_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`kitchen_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`kitchen_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`kitchen_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`kitchen_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`kitchen_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`kitchen_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_kitchenMTH_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`kitchenMTH_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`kitchenMTH_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`kitchenMTH_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`kitchenMTH_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`kitchenMTH_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`kitchenMTH_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`kitchenMTH_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`kitchenMTH_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`kitchenMTH_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_dining_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`dining_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`dining_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`dining_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`dining_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`dining_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`dining_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`dining_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`dining_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`dining_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_living_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`living_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`living_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`living_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`living_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`living_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`living_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`living_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`living_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`living_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_computer_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`computer_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`computer_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`computer_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`computer_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`computer_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`computer_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`computer_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`computer_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`computer_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_guest_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`guest_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`guest_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`guest_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`guest_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`guest_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`guest_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`guest_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`guest_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`guest_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_master_motion ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`master_motion`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`master_motion`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`master_motion` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`master_motion` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`master_motion` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`master_motion` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`master_motion` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`master_motion` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`master_motion` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_Play ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`play_data`;
        IF @rowCount > 1 THEN
            SELECT MAX(Id) INTO @theId FROM `demay_farm`.`play_data`;
            SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`play_data` WHERE Id = @theId LIMIT 1;
            SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`play_data` WHERE Id = @theId - 1 LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`play_data` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`play_data` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting first rows.";
            INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

/*

CREATE OR REPLACE TABLE `demay_farm`.`BoolTableTemplate` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Time` datetime(6) DEFAULT NULL,
  `value` tinyint(1) DEFAULT NULL,
  `duration` float DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `demay_farm`.`pump_data` LIKE BoolTableTemplate;
CREATE TABLE `demay_farm`.`pressure_pump` LIKE BoolTableTemplate;
CREATE TABLE `demay_farm`.`submersible_pump` LIKE BoolTableTemplate;

CREATE TABLE `demay_farm`.`kitchen_motion` LIKE BoolTableTemplate;
CREATE TABLE `demay_farm`.`dining_motion` LIKE BoolTableTemplate;
CREATE TABLE `demay_farm`.`living_motion` LIKE BoolTableTemplate;
CREATE TABLE `demay_farm`.`computer_motion` LIKE BoolTableTemplate;
CREATE TABLE `demay_farm`.`guest_motion` LIKE BoolTableTemplate;
CREATE TABLE `demay_farm`.`master_motion` LIKE BoolTableTemplate;


CREATE TABLE `demay_farm`.`play_data` LIKE BoolTableTemplate;

CALL add_pt_to_Play('2021-06-04 10:30:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:31:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:32:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:33:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:34:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:35:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:36:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:37:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:38:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:39:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:45:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:46:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:47:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:48:00.123456', 0); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:52:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:53:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:54:00.123456', 1); SELECT * FROM play_data;
CALL add_pt_to_Play('2021-06-04 10:55:00.123456', 1); SELECT * FROM play_data;

DROP TABLE IF EXISTS Play_data;

--*/

/*
This didn't work because for some reason "WHERE device = @newDev" clause is ignored.
DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_Play2 ( newTime DATETIME(6), newval BOOLEAN, device VARCHAR(255)) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;
        SET @newDev = device;
        SET @iD = 0;
        SET @iDm1 = 0;

        SELECT IFNULL(Id, 0), Time, Value, device INTO @iD, @prevT, @prevVal, @prevDev FROM `demay_farm`.`play_data` WHERE device = @newDev ORDER BY Id DESC LIMIT 1;
        SELECT IFNULL(Id, 0), Time, Value, device  INTO @iDm1, @prevTm1, @prevValm1, @prevDevm1 
            FROM `demay_farm`.`play_data` 
            WHERE Id < @Id AND device = @newDev
            ORDER BY Id DESC LIMIT 1;
        select @iD, @prevT, @prevVal, @prevDev, @newDev;
        select @iDm1, @prevTm1, @prevValm1, @prevDevm1, @newDev;
        -- SELECT IFNULL(Id,0) INTO @theId FROM `demay_farm`.`play_data` WHERE device = @newDev ORDER BY Id DESC LIMIT 1;
        -- SELECT IFNULL(Id,0) INTO @rowCount2 FROM `demay_farm`.`play_data` WHERE device = @newDev AND ID < @rowCount;
        IF @iD = 0 THEN
            select "Inserting first row.";
            INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, @newT, @newDev, @newV, 0);
        ELSEIF @iDm1 = 0 THEN
            select "Inserting second row.";
            INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, @newT, @newDev, @newV, 0);
        -- SELECT count(device) INTO @rowCount FROM `demay_farm`.`play_data` WHERE device = @newDev;
        -- SELECT count(device) AS RowCount, @newDev FROM `demay_farm`.`play_data` WHERE device = @newDev;
        -- select CONCAT("Row count for ", @newDev, " is ", @rowCount);
        ELSE
            -- SELECT MAX(Id) INTO @theId FROM `demay_farm`.`play_data` WHERE device = @newDev;
            -- SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`play_data` WHERE Id = @theId LIMIT 1;
            -- SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 
            --   FROM `demay_farm`.`play_data` 
            --   WHERE Id < @theId AND device = @newDev
            --   ORDER BY Id DESC LIMIT 1;
            -- select "Update the time on the last row to the current time (minus 1 microsec)";
            UPDATE `demay_farm`.`play_data` SET Time = TIMESTAMPADD(MICROSECOND, -1, @newT) WHERE Id = @Id;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            -- select "Update the duration on the last TWO rows to the current duration.";
            UPDATE `demay_farm`.`play_data` SET duration = @dur WHERE Id = @iD OR Id = @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, @newT, @newDev, @newV, 0);
                INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newDev, @newV, 0);
            END IF;
        END IF;
    END;
$$

DELIMITER ;

CREATE OR REPLACE TABLE `booltabletemplate2` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Time` datetime(6) DEFAULT NULL,
  `device` varchar(255) NOT NULL,
  `value` tinyint(1) DEFAULT NULL,
  `duration` float DEFAULT NULL,
  INDEX (device),
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE Play_data like BoolTableTemplate2;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:30:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:30:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:31:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:31:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:32:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:32:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:33:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:34:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:35:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:33:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:34:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:36:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:37:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:38:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:39:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:35:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:36:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:37:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:38:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:39:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:45:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:46:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:47:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:48:00.123456', 0, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:45:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:46:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:47:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:48:00.123456', 0, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:52:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:53:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:54:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDev'; CALL add_pt_to_Play2('2021-06-04 10:55:00.123456', 1, 'playDev'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:52:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:53:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:54:00.123456', 1, 'playDe2'); SELECT * FROM play_data;
SET @newDev = 'playDe2'; CALL add_pt_to_Play2('2021-06-04 11:55:00.123456', 1, 'playDe2'); SELECT * FROM play_data;

DROP TABLE IF EXISTS Play_data;
*/

