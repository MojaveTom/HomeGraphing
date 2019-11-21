DELIMITER //
CREATE OR REPLACE FUNCTION dewPt(t DOUBLE, rh DOUBLE) RETURNS DOUBLE DETERMINISTIC
BEGIN
  DECLARE tc DOUBLE;
  DECLARE pd DOUBLE;
  DECLARE dpC DOUBLE;
  SET tc = ((t-32)*5.0)/9.0;
  SET pd = POW((rh/100.0), 0.125);
  SET dpC = (pd*(112.0+(0.9*tc)))+(0.1*tc)-112.0;
  return (dpC * 9.0)/5.0 +32.0;
END //

CREATE OR REPLACE FUNCTION equivRH(dp DOUBLE, t DOUBLE) RETURNS DOUBLE DETERMINISTIC
BEGIN
  DECLARE tc DOUBLE;
  DECLARE dpC DOUBLE;
  SET tc = ((t-32)*5.0)/9.0;
  SET dpC = ((dp-32)*5.0)/9.0;
  return 100.0*POW((112.0-(0.1*tc)+dpC)/(112.0+(0.9*tc)), 8.0);
END //

DELIMITER ;

CREATE OR REPLACE VIEW insideRH AS SELECT
  date as time,
  tempf as outTemp,
  humidity as outHum,
  tempinf as inTemp,
  humidityin as inHum,
  dewPoint as outDP,
  equivRH(dewPoint, tempinf) as equivInRh
  from weather;
