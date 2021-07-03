
CREATE TABLE IF NOT EXISTS `demay_farm`.`pump_data` LIKE `demay_farm`.`BoolTableTemplate`;


delimiter |
FOR rec IN (SELECT rectime, (json_value(message, '$.PumpRun') = 'ON') AS val FROM mqttmessages WHERE topic = 'e8db84e569cf/data' and rectime > '2021-06-03' ) -- (select max(Time) from pump_data) ) -- 
    DO
        SELECT MAX(Id) INTO @theId FROM `demay_farm`.`pump_data`;
        SELECT Id, Time, Value INTO @iD, @prevT, @prevVal FROM `demay_farm`.`pump_data` WHERE Id = @theId LIMIT 1;
        SELECT Id, Time, Value INTO @iDm1, @prevTm1, @prevValm1 FROM `demay_farm`.`pump_data` WHERE Id = @theId - 1 LIMIT 1;
        call add_pt_to_Pump(rec.rectime, rec.val);
    END FOR;
|
delimiter ;
