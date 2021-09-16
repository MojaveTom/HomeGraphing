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
CREATE TABLE IF NOT EXISTS `demay_farm`.`motion` (
  `Id` bigint(20) NOT NULL AUTO_INCREMENT,
  `Time` datetime(6) NOT NULL,
  `Sensor` varchar(255) NOT NULL,
  `value` BOOLEAN NOT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
$$
DELIMITER ;

ALTER TABLE motion AUTO_INCREMENT = 1;

INSERT IGNORE INTO `demay_farm`.`motion` (Time, Sensor, value)
  SELECT RecTime, "Computer Room", json_value(message, '$.MotionDetected') = 'ON' FROM `demay_far,`.`mqttmessages`
  WHERE topic = 'a020a613638e/data' AND SUBSTR(json_value(message, '$.PublishReason'),1,1) = 'M' ;

DELIMITER $$
CREATE OR REPLACE TRIGGER SaveInterestingMqtt AFTER INSERT ON `demay_farm`.`mqttmessages` 
FOR EACH ROW
`whole_proc`:
BEGIN
    /* Pressure Booster pump data.  */
    IF NEW.topic = 'dc4f220da30c/data' OR NEW.topic = 'e8db84e569cf/data' THEN
        CALL add_pt_to_Pump(NEW.rectime, (json_value(NEW.message, '$.PumpRun') = 'ON') );
        LEAVE `whole_proc`;
    END IF;
    /* Submersible and Pressure pump data.  */
    IF NEW.topic = 'a020a61228ea/data' THEN
        CALL add_pt_to_PressurePump(NEW.rectime, (json_value(NEW.message, '$.PressurePump') = 'ON') );
        CALL add_pt_to_SubmersiblePump(NEW.rectime, (json_value(NEW.message, '$.SubmersiblePump') = 'ON') );
        LEAVE `whole_proc`;
    END IF;
    /* Driveway Alarm data.  */
    IF NEW.topic = 'b827eb25526d/Driveway' /*AND (json_value(NEW.message, '$.AlarmState') = 'ON')*/ THEN
        INSERT INTO `demay_farm`.`driveway_alarms` VALUES (DEFAULT, json_value(NEW.message, '$.AlarmTime'), json_value(NEW.message, '$.AlarmState'));
        LEAVE `whole_proc`;
    END IF;
    /* Computer Room MTH: message example
    {"MachineID":"a020a613638e","SampleTime":"2021-09-15 21:18:43-0700","MotionDetected":"OFF","Temperature":84.92,"Humidity":24.9,"PublishReason":"M--"}
    */
    IF NEW.topic = 'a020a613638e/data' AND SUBSTR(json_value(NEW.message, '$.PublishReason'),1,1) = 'M' THEN
        INSERT INTO `demay_farm`.`motion` VALUES (DEFAULT, NEW.rectime, 'Computer Room', json_value(NEW.message, '$.MotionDetected') = 'ON');
        LEAVE `whole_proc`;
    END IF;
    /* Master Bed MTH: message example
    {"MachineID":"cc50e3550d5b","UnixTime":1631768050,"SampleTime":"2021-09-15 21:54:10-0700","MotionDetected":"ON","Temperature":80.2,"Humidity":25.4,"PublishReason":"M--"}
    */
    IF NEW.topic = 'cc50e3550d5b/data' AND SUBSTR(json_value(NEW.message, '$.PublishReason'),1,1) = 'M' THEN
        INSERT INTO `demay_farm`.`motion` VALUES (DEFAULT, NEW.rectime, 'Master Bed', json_value(NEW.message, '$.MotionDetected') = 'ON');
        LEAVE `whole_proc`;
    END IF;
END;
$$
DELIMITER ;
