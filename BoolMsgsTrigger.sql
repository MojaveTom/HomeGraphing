DELIMITER |
CREATE TABLE IF NOT EXISTS `demay_farm`.`args`
(
    Id BIGINT AUTO_INCREMENT PRIMARY KEY, -- primary key column
    theId_max BIGINT,
    theId BIGINT,
    newT DATETIME(6),
    newV BOOLEAN,
    prevT DATETIME(6),
    prevVal BOOLEAN,
    iDm1 BIGINT,
    prevTm1 DATETIME(6),
    prevValm1 boolean
);
|

CREATE OR REPLACE PROCEDURE ShowArgs(newT DATETIME(6), newV BOOL)
BEGIN
    INSERT INTO args VALUES (DEFAULT, @theId, @iD, newT, newV, @prevT, @prevVal, @iDm1, @prevTm1, @prevValm1);
END;
|
DELIMITER ;

DELIMITER $$
CREATE OR REPLACE TRIGGER UpdateBoolVals AFTER INSERT ON `demay_farm`.`mqttmessages` FOR EACH ROW
BEGIN
    IF NEW.topic = 'dc4f220da30c/data' OR NEW.topic = 'e8db84e569cf/data' THEN
        CALL add_pt_to_Pump(NEW.rectime, (json_value(NEW.message, '$.PumpRun') = 'ON') );
    END IF;
    IF NEW.topic = 'a020a61228ea/data' THEN
        CALL add_pt_to_PressurePump(NEW.rectime, (json_value(NEW.message, '$.PressurePump') = 'ON') );
        CALL add_pt_to_SubmersiblePump(NEW.rectime, (json_value(NEW.message, '$.SubmersiblePump') = 'ON') );
    END IF;
END;
$$
DELIMITER ;
