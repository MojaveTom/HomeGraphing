#!/usr/bin/env python3

'''
# This is how to get weather information from ambientweather.net:
#  It should be in its own program that inserts the data to the database at regular
#  intervals.  We can get about 24 hours at a time (288) data points; but we can
#  specify the ending date/time we are interested in retrieving.
# Probably should run a cron job every 12 hours to get the previous 24 hours of data
#  and let the database sort out the duplicates.

Use the following command from bash in this directory to install this program to run every 900 seconds (15 minutes)
../MqttUtils/InstallAgent.py --IAa '[{"StartInterval": 900}]' RetrieveAmbientWeatherData.py

'''
### Python3 Library documentation   #   https://docs.python.org/3/library
import time             #   https://docs.python.org/3/library/time.html
import datetime         #   https://docs.python.org/3/library/datetime.html
from datetime import date           #   https://docs.python.org/3/library/datetime.html#date-objects
from datetime import timedelta      #   https://docs.python.org/3/library/datetime.html#timedelta-objects
from datetime import datetime as dt #   https://docs.python.org/3/library/datetime.html#datetime-objects
from datetime import time as dtime  #   https://docs.python.org/3/library/datetime.html#time-objects
import os               #   https://docs.python.org/3/library/os.html
import sys              #   https://docs.python.org/3/library/sys.html
import argparse         #   https://docs.python.org/3/library/argparse.html
import configparser     #   https://docs.python.org/3/library/configparser.html
import logging          #   https://docs.python.org/3/library/logging.html
import logging.config   #   https://docs.python.org/3/library/logging.config.html
import logging.handlers #   https://docs.python.org/3/library/logging.handlers.html
import json             #   https://docs.python.org/3/library/json.html
import requests         #   https://2.python-requests.org/en/master/user/quickstart/

import pymysql as mysql             #   https://pymysql.readthedocs.io/en/latest/modules/index.html
from pymysql.err import Error as DbError    #   https://github.com/PyMySQL/PyMySQL/blob/master/pymysql/err.py
from ambient_api import ambientapi  #   https://ambientweather.docs.apiary.io/#
from math import ceil as ceil       #   https://docs.python.org/3/library/math.html


ProgName, ext = os.path.splitext(os.path.basename(sys.argv[0]))
ProgPath = os.path.dirname(os.path.realpath(sys.argv[0]))
logConfFileName = os.path.join(ProgPath, ProgName + '_loggingconf.json')
if os.path.isfile(logConfFileName):
    try:
        with open(logConfFileName, 'r') as logging_configuration_file:
            config_dict = json.load(logging_configuration_file)
        if 'log_file_path' in config_dict:
            logPath = os.path.expandvars(config_dict['log_file_path'])
            os.makedirs(logPath, exist_ok=True)
        else:
            logPath=""
        for p in config_dict['handlers'].keys():
            if 'filename' in config_dict['handlers'][p]:
                config_dict['handlers'][p]['filename'] = os.path.join(logPath, config_dict['handlers'][p]['filename'])
        logging.config.dictConfig(config_dict)
    except Exception as e:
        print("loading logger config from file failed.")
        print(e)
        pass

logger = logging.getLogger(__name__)
logger.info('logger name is: "%s"', logger.name)
logging.getLogger('matplotlib.axes._base').setLevel('WARNING')      # turn off matplotlib info & debug messages
logging.getLogger('matplotlib.font_manager').setLevel('WARNING')

def GetConfigFilePath():
    fp = os.path.join(ProgPath, 'secrets.ini')
    if not os.path.isfile(fp):
        fp = os.environ['PrivateConfig']
        if not os.path.isfile(fp):
            logger.error('No configuration file found.')
            sys.exit(1)
    logger.info('Using configuration file at: %s', fp)
    return fp

#######################   GLOBALS   ########################
ServerTimeFromUTC = timedelta(hours=0)
RequiredConfigParams = frozenset(('ambient_endpoint', 'ambient_api_key', 'ambient_application_key', 'inserter_host', 'inserter_schema', 'inserter_port', 'inserter_user', 'inserter_password', 'weather_table'))

DBConn = None
dontWriteDb = True
tzsavesql = "SET @oldtz=@@session.time_zone"
tzsetUTC  = "SET @@session.time_zone='+00:00'"
tzrestoresql = "SET @@session.time_zone=@oldtz"
logger.debug('tzsavesql: %s', tzsavesql)
logger.debug('tzsetUTC: %s', tzsetUTC)
logger.debug('tzrestoresql: %s', tzrestoresql)

#  Generate a timezone for  LocalStandardTime
#  Leaving off zone name from timezone creator generates UTC based name which may be more meaningful.
localStandardTimeZone = datetime.timezone(-datetime.timedelta(seconds=time.timezone))
logger.debug('LocalStandardTime ZONE is: %s'%localStandardTimeZone)


#######################   FUNCTIONS   ########################

def GetDatabaseHoles(conn, Table, HoleSize):
    '''
SQL commands to view gaps:

create temporary table w1 like weather;
alter table w1 drop primary key;
alter table w1 add column id int auto_increment primary key first;
insert into w1 (dateutc, date) select dateutc, date from weather order by dateutc;
select  wB.date as beginTime,  wA.date as endTime, round((wA.dateutc - wB.dateutc)/60000) as diff from w1 as wA inner join w1 as wB on wA.id=wB.id+1 where (wA.dateutc - wB.dateutc)/60000 > 20;
drop table w1;
'''
    beginTimes = list()
    endTimes = list()
    logger.debug('Auto detecting gaps in weather table.')
    q = 'CREATE TEMPORARY TABLE w1 (id BIGINT AUTO_INCREMENT PRIMARY KEY, dateutc BIGINT, date DATETIME)'
    logger.debug('Create temporary table.  "%s"'%q)
    conn.execute(q)
    logger.debug('Copy rows from weather to temporary table.')
    conn.execute('INSERT INTO w1 (dateutc, date) SELECT dateutc, date FROM %s ORDER BY dateutc'%Table)
    gapQuery = 'SELECT  wB.dateutc,  wA.dateutc, ROUND((wA.dateutc - wB.dateutc)/60000), wB.date, wA.date FROM w1 AS wA INNER JOIN w1 AS wB ON wA.id=wB.id+1 WHERE (wA.dateutc - wB.dateutc)/60000 > %s'%HoleSize
    logger.debug('Select time gaps with query: "%s"'%gapQuery)
    conn.execute(gapQuery)
    for row in conn:
        b = row[0]
        e = row[1]
        beginTimes.append(b)
        endTimes.append(e)
        logger.debug('Appending %s to beginTimes, %s to endTimes, because the gap was %s'%(row[3], row[4], row[2]))
    logger.debug('Auto detected gaps are: begin %s, end %s'%(beginTimes, endTimes))
    logger.debug('Drop temporary table.')
    conn.execute('drop table w1')

    return beginTimes, endTimes

def main():
    global DBConn, dontWriteDb, localStandardTimeZone
    logger.debug("Entered main.")
    parser = argparse.ArgumentParser(
        description='Retrieve weather data from Ambient.net.')
    parser.add_argument("-o", "--oldData", dest="desiredFirst", action="store", help="Set desired first database date.")
    parser.add_argument("-s", "--holeSize", dest="holeSize", action="store", help="If specified, look for holes in weather data bigger than this AND try to fill them.")
    parser.add_argument("-n", "--nullHoles", dest="doNull", action="store_true", help="Fill remaining holes with NULL records so hole won't be found again.")
    parser.add_argument("-W", "--dontWriteToDB", dest="noWriteDb", action="store_true", default=False, help="Don't write to database [during debug defaults to True].")
    parser.add_argument("-v", "--verbosity", dest="verbosity",
                        action="count", help="Increase output verbosity", default=0)
    args = parser.parse_args()
    Verbosity = args.verbosity
    dontWriteDb = args.noWriteDb

    config = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
    configFile = GetConfigFilePath()

    config.read(configFile)
    cfgSection = os.path.basename(sys.argv[0])+"/"+os.environ['HOST']
    logger.info("INI file cofig section is: %s", cfgSection)
    if not config.has_section(cfgSection):
        logger.critical('Config file "%s", has no section "%s".', configFile, cfgSection)
        sys.exit(2)
    if set(config.options(cfgSection)) < RequiredConfigParams:
        logger.critical('Config  section "%s" does not have all required params: "%s", it has params: "%s".', cfgSection, RequiredConfigParams, set(config.options(cfgSection)))
        sys.exit(3)

    cfg = config[cfgSection]

    user = cfg['inserter_user']
    pwd  = cfg['inserter_password']
    host = cfg['inserter_host']
    port = int(cfg['inserter_port'])
    myschema = cfg['inserter_schema']
    endpoint = cfg['ambient_endpoint']
    api_key = cfg['ambient_api_key']
    app_key = cfg['ambient_application_key']
    weather_table = cfg['weather_table']
    myWeatherDevice = cfg['MAC_address']

    logger.debug('host: %s, port: %d, user: %s, pwd: %s, schema: %s'%(host, port, user, pwd, myschema))

    DBConn = mysql.connect(host=host, port=port, user=user, password=pwd, database=myschema, binary_prefix=True, charset='utf8mb4')
    logger.debug('DBConn is: %s'%DBConn)

    with DBConn.cursor() as Iconn:
        logger.info("Insertion connection to database established.")
        Ambient_api = ambientapi.AmbientAPI(AMBIENT_ENDPOINT=endpoint \
            , AMBIENT_API_KEY=api_key \
            # log_levels are: debug, info, warning, error, critical, console (just prints message)
            # log_file is ignored if log_level is 'console'
            , AMBIENT_APPLICATION_KEY=app_key \
            , log_level='console' if Verbosity >= 1 else None \
            , log_file='ambient.log' if Verbosity >= 1 else None \
            )

        devices = Ambient_api.get_devices()
        logger.debug("Weather stationS info: %s", devices)
        device = None
        for d in devices:
            logger.debug("Weather station info: %s", d.info)
            logger.debug("MAC address of weather station: %s", d.mac_address)
            if d.mac_address == myWeatherDevice.upper():
                device = d
                logger.debug('Found desired weather station: %s' % myWeatherDevice)
                break
            pass

        if device is None:
            logger.critical('Desired weather station data not found at AmbientWeather. %s' % myWeatherDevice)
            exit(1)

        Iconn.execute("SELECT date FROM `"+myschema+"`.`"+weather_table+"` ORDER BY date DESC LIMIT 2")
        lastTimeInDb = None
        nextToLastTime = None
        for result in Iconn:
            if lastTimeInDb is None: lastTimeInDb = result[0]
            elif nextToLastTime is None:
                nextToLastTime = result[0]
                break
        logger.debug('lastTimeInDb: %s, nextToLastTime: %s', lastTimeInDb, nextToLastTime)
        Iconn.execute("SELECT dateutc FROM `"+myschema+"`.`"+weather_table+"` ORDER BY date LIMIT 1")
        firstTimeInDb = None
        for result in Iconn:
            firstTimeInDb = result[0]
        logger.debug('firstTimeInDb: %s ms', firstTimeInDb)
        if lastTimeInDb and nextToLastTime:
            timeDiff = lastTimeInDb - nextToLastTime
        else:
            timeDiff = timedelta(minutes=5)
        if timeDiff > timedelta(minutes=5):
            timeDiff = timedelta(minutes=5)
        nowTime = dt.now()
        if lastTimeInDb:
            numNew = int((nowTime - lastTimeInDb) / timeDiff) + 2    # Get a couple duplicates "just in case"
        else:
            numNew = 288        # This only happens if nothing in database.
        logger.info("lastTimeInDb: %s; nextToLastTime: %s; timeDiff: %s", lastTimeInDb, nextToLastTime, timeDiff)
        logger.info("nowTime: %s", nowTime)
        logger.info("Number of new data points is (plus extras): %s", numNew)

        ## Set time zone for my connection to UTC, so times from ambient will be correct.
        try:
            Iconn.execute(tzsavesql)
            Iconn.execute(tzsetUTC)
        except DbError as e:
            _ = e
            logger.error("Caught DbError exception settinmg time_zone: %s", e)
            logger.exception(e)
            DBConn.rollback()
            pass

        time.sleep(2)       # Wait a while for Ambient server to recover: at least 1 sec.

        logger.debug('Get %s data points from Ambient Weather.'%str(numNew))

        ################    get data from Ambient
        wdata = device.get_data(limit=numNew)

        if len(wdata) > 0:
            logger.debug("Length, type of weather device data: %s, %s, %s", len(wdata), type(wdata), type(wdata[0]))
            logger.info("Weather device data: %s", wdata)
            for dp in wdata:
                insertsql = "INSERT IGNORE INTO `"+myschema+"`.`"+weather_table+"` "+str(tuple(dp.keys())).replace("'", "") \
                    +" VALUES "+str(tuple(dp.values())).replace("Z","")+" ON DUPLICATE KEY UPDATE date = VALUES(date)"
                logger.debug("Insert SQL: %s", insertsql)
                if not dontWriteDb:
                    try:
                        Iconn.execute(insertsql)
                    except DbError as e:
                        _ = e
                        logger.warning("Caught DbError exception inserting data: %s", e)
                        logger.exception(e)
                        DBConn.rollback()
                        break
                else:
                    logger.debug('Did NOT write to database.')
        else:
            logger.info("No new weather data retrieved.")

        beginTime = round(datetime.datetime.utcnow().timestamp()*1000) # number millisec since Epoch
        endTime = beginTime
        beginTimes = list()
        endTimes = list()

        holeSize = None
        if args.holeSize is not None:
            if int(args.holeSize) < 5:
                logger.warning('Hole size must be larger than 5 min.  You specified: %s.'%args.holeSize)
                logger.warning('Ignoring hole filling.')
                holeSize = None
            else:
                holeSize = int(args.holeSize)

        #####  Find holes
        if holeSize is not None:
            logger.debug('Looking for holes in the weather data larger that %s min.'%holeSize)
            beginTimes, endTimes = GetDatabaseHoles(Iconn, weather_table, holeSize)
            logger.debug('Hole begins, ends %s'%list(zip(beginTimes, endTimes)))

        firstDate = None
        if args.desiredFirst is not None:
            try:
                firstDate = dt.fromisoformat(args.desiredFirst).timestamp()*1000        # millisec since epoch
                logger.info("Desired first date is: %s ms", str(firstDate))
            except Exception as e:
                logger.error("Old data retrieval aborted because given time was ill-formatted.")
                logger.info("--oldData time was specified as: %s", args.desiredFirst)
                logger.exception(e)
        else:
            logger.info("No weather data before existing is desired.")

        if (firstDate is not None) and (firstTimeInDb is not None) and (firstDate < firstTimeInDb):
            beginTimes.append(firstDate)
            endTimes.append(firstTimeInDb)
            pass
        for beginTime, endTime in list(zip(beginTimes, endTimes)):
            logger.info("Trying to retrieve historical weather data between: %s and: %s", beginTime, endTime)
            time.sleep(2)       # wait for ambient server to recover
            timeDiffMilliSec = round(timeDiff.total_seconds()*1000)
            numReq = ceil((endTime - beginTime) / timeDiffMilliSec) + 2
            endTime = endTime + timeDiffMilliSec        # overlap the ends of the gap by 1 point.
            if numReq > 288:
                numReq = 288
            logger.debug('Getting %s records ending at %s ms'%(numReq, endTime))

            #########   Get weather data from Ambient
            wdata = device.get_data(limit = numReq, end_date = endTime)

            if len(wdata) > 0:
                logger.debug("Length, type of weather device data: %s, %s, %s", len(wdata), type(wdata), type(wdata[0]))
                logger.info("Weather device data: %s", wdata)
                for dp in wdata:
                    insertsql = "INSERT IGNORE INTO `"+myschema+"`.`"+weather_table+"` " \
                            + str(tuple(dp.keys())).replace("'", "") \
                            + " VALUES " \
                            + str(tuple(dp.values())).replace("Z","") \
                            + " ON DUPLICATE KEY UPDATE date = VALUES(date)"
                    logger.debug("Insert SQL: %s", insertsql)
                    if not dontWriteDb:
                        try:
                            Iconn.execute(insertsql)
                        except DbError as e:
                            _ = e
                            logger.warning("Caught DbError exception inserting data: %s", e)
                            logger.exception(e)
                            DBConn.rollback()
                            break
                    else:
                        logger.debug('Did NOT write to database.')
            else:
                logger.info("No historical data retrieved.")

        #####  Find unfillable holes -- that is holes that couldn't be filled from above
        if (args.doNull) and (holeSize is not None):
            logger.debug('Looking for UNFILLED holes in the weather data larger that %s min.'%holeSize)
            beginTimes, endTimes = GetDatabaseHoles(Iconn, weather_table, holeSize)
            logger.debug('Hole begins, ends %s'%list(zip(beginTimes, endTimes)))
            for beginTime, endTime in list(zip(beginTimes, endTimes)):
                logger.info("Filling weather data between: %s and: %s with NULLs", beginTime, endTime)
                timeDiffMilliSec = 5*60*1000       # 5 minutes as millisec
                for theTime in range(beginTime, endTime, timeDiffMilliSec):
                    theDate = datetime.datetime.utcfromtimestamp(theTime/1000).isoformat(sep=' ')
                    insertsql = "INSERT IGNORE INTO `{schema}`.`{table}` (dateutc, date) VALUES (%d, '%s') ON DUPLICATE KEY UPDATE date = VALUES(date)".format(schema=myschema, table=weather_table)
                    logger.debug("Insert SQL: %s", Iconn.mogrify(insertsql%(theTime, theDate)))
                    if not dontWriteDb:
                        try:
                            Iconn.execute(insertsql%(theTime, theDate))
                        except DbError as e:
                            _ = e
                            logger.warning("Caught DbError exception inserting data: %s", e)
                            logger.exception(e)
                            DBConn.rollback()
                            break
                    else:
                        logger.debug('Did NOT write to database.')

        try:
            Iconn.execute(tzrestoresql)
            # DBConn.commit()
        except DbError as e:
            _ = e
            logger.warning("Caught DbError exception restoring timezone: %s", e)
            logger.exception(e)
            DBConn.rollback()
            pass
        DBConn.commit()

if __name__ == "__main__":
    logger.info('             ##############   RetrieveAmbiendWeatherData --- Starting ---  #################')
    main()
    logger.info('             ##############   RetrieveAmbiendWeatherData --- All Done ---  #################')
    logging.shutdown()
    pass
