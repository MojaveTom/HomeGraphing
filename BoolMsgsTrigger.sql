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
CREATE TABLE IF NOT EXISTS `demay_farm`.`driveway_alarms` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Time` datetime(6) DEFAULT NULL,
  `value` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
$$
DELIMITER ;

DELIMITER $$
CREATE OR REPLACE TRIGGER UpdateBoolVals AFTER INSERT ON `demay_farm`.`mqttmessages` FOR EACH ROW
BEGIN
    IF NEW.topic = 'dc4f220da30c/data' OR NEW.topic = 'e8db84e569cf/data' THEN
        CALL add_pt_to_Pump(NEW.rectime, (json_value(NEW.message, '$.PumpRun') = 'ON') );
    ELSEIF NEW.topic = 'a020a61228ea/data' THEN
        CALL add_pt_to_PressurePump(NEW.rectime, (json_value(NEW.message, '$.PressurePump') = 'ON') );
        CALL add_pt_to_SubmersiblePump(NEW.rectime, (json_value(NEW.message, '$.SubmersiblePump') = 'ON') );
    ELSEIF NEW.topic = 'b827eb25526d/Driveway' /*AND (json_value(NEW.message, '$.AlarmState') = 'ON')*/ THEN
        INSERT INTO `demay_farm`.`driveway_alarms` VALUES (DEFAULT, json_value(NEW.message, '$.AlarmTime'), json_value(NEW.message, '$.AlarmState'));
    END IF;
END;
$$
DELIMITER ;
