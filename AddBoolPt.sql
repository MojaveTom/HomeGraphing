/*
 *  Call this procedure each time a new row of pressure booster pump data is added to the
 *  mqttmessages table.  It updates the pump_data table with extracted information.
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
 */

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_Pump ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`pump_data`;
        IF @rowCount > 1 THEN
            UPDATE `demay_farm`.`pump_data` SET Time = @newT WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            UPDATE `demay_farm`.`pump_data` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting", "first rows.";
            INSERT INTO `demay_farm`.`pump_data` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$
DELIMITER ;

DELIMITER $$

CREATE OR REPLACE PROCEDURE add_pt_to_Play ( newTime DATETIME(6), newval BOOLEAN) MODIFIES SQL DATA
    BEGIN
        SET @newT = newTime;
        SET @newV = newval;
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`play_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`play_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`play_data` WHERE Id = @theId - 1 LIMIT 1;

        SELECT count(*) INTO @rowCount FROM `demay_farm`.`play_data`;
        IF @rowCount > 1 THEN
            UPDATE `demay_farm`.`play_data` SET Time = @newT WHERE Id = @theId;
            SET @dur = UNIX_TIMESTAMP(@newT) - UNIX_TIMESTAMP(@prevTm1);
            UPDATE `demay_farm`.`play_data` SET duration = @dur WHERE Id >= @iDm1;
            IF (@prevVal != @newV) THEN
                INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, @newT, @newV, 0);
                INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, TIMESTAMPADD(MICROSECOND, 1, @newT), @newV, 0);
            END IF;
        ELSE
            -- select "Inserting", "first rows.";
            INSERT INTO `demay_farm`.`play_data` VALUES (DEFAULT, @newT, @newV, 0);
        END IF;
    END;
$$

DELIMITER ;

/*
CREATE TABLE Play_data like BoolTableTemplate;
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
