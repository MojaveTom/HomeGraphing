#!/usr/bin/env python3

'''
# This is how to get weather information from ambientweather.net:
#  It should be in its own program that inserts the data to the database at regular
#  intervals.  We can get about 24 hours at a time (288) data points; but we can
#  specify the ending date/time we are interested in retrieving.
# Probably should run a cron job every 12 hours to get the previous 24 hours of data
#  and let the database sort out the duplicates.

'''

from sqlalchemy import create_engine
from sqlalchemy import sql, exc
import pymysql as mysql
import pymysql.err as Error
import time
import datetime
from datetime import date
from datetime import timedelta
from datetime import datetime
import argparse
import time

from ambient_api import ambientapi
import json

#######################   GLOBALS   ########################
Verbosity = 0
callStack = []
ServerTimeFromUTC = timedelta(hours=0)
ServerTimeFromUTCSec = 0

def main():
    global Verbosity, callStack, ServerTimeFromUTC, ServerTimeFromUTCSec
    callStack.append('main')
    if Verbosity>= 1: print(callStack, "Entered main.", flush=True)
    parser = argparse.ArgumentParser(
        description='Retrieve weather data from Ambient.net.')
    parser.add_argument("-o", "--oldData", dest="desiredFirst", action="store", help="Set desired first database date.")
    parser.add_argument("-v", "--verbosity", dest="verbosity",
                        action="count", help="Increase output verbosity", default=0)
    args = parser.parse_args()
    Verbosity = args.verbosity
    firstDate = None
    if args.desiredFirst is not None:
        try:
            firstDate = datetime.fromisoformat(args.desiredFirst)
            if Verbosity >= 1:
                print(callStack, "Desired first date is: ", str(firstDate))
        except:
            if Verbosity >= 0:
                print(callStack, "Old data retrieval aborted because given time was ill-formatted.")
            if Verbosity >= 1:
                print(callStack, "--oldData time was specified as: ", args.desiredFirst)
    else:
        if Verbosity >= 1:
            print(callStack, "No historical weather data desired.")

    config = configparser.ConfigParser(interpolation=configparser.ExtendedInterpolation())
    config.read('secrets.ini')
    cfgSection = os.path.basename(sys.argv[0])
    if Verbosity >= 2: print(callStack, "INI file cofig section is:", cfgSection)
    cfg = config[cfgSection]

    user = cfg['ss_inserter_user']
    pwd  = cfg['ss_inserter_password']
    host = cfg['ss_inserter_host']
    port = cfg['ss_inserter_port']
    myschema = cfg['ss_inserter_schema']
    endpoint = cfg['ambient_endpoint']
    api_key = cfg['ambient_api_key']
    ap_key - cfg['ambient_application_key']

    connstr = 'mysql+pymysql://{user}:{pwd}@{host}:{port}/{schema}'.format(user=user, pwd=pwd, host=host, port=port, schema=myschema)
    if Verbosity >= 1: print(callStack, "SS weather database connection string:", connstr)
    InserterEng = create_engine(connstr, echo = True if Verbosity>=2 else False)
    if Verbosity >= 1:
        print(callStack, InserterEng, flush=True)
    with InserterEng.connect() as Iconn, Iconn.begin():
        if Verbosity >= 1:
            print(callStack, "Insertion connection to database established.", flush=True)
        result = Iconn.execute("SELECT timestampdiff(hour, utc_timestamp(), now());")
        for row in result:
            ServerTimeFromUTC = timedelta(hours=row[0])
            ServerTimeFromUTCSec = ServerTimeFromUTC.days*86400+ServerTimeFromUTC.seconds
        if Verbosity >= 1:
            print(callStack, "SS Server time offset from UTC: ", ServerTimeFromUTC, flush=True)
            print(callStack, "SS Server time offset from UTC (seconds): ",
                ServerTimeFromUTCSec, flush=True)
        Ambient_api = ambientapi.AmbientAPI(AMBIENT_ENDPOINT=endpoint \
            , AMBIENT_API_KEY=api_key \
            # log_levels are: debug, info, warning, error, critical, console (just prints message)
            # log_file is ignored if log_level is 'console'
            , AMBIENT_APPLICATION_KEY=app_key \
            , log_level='console' if Verbosity >= 2 else None \
            # , log_file='ambient.log' \
            )

        device = Ambient_api.get_devices()[0]
        if Verbosity >= 1:
            print(callStack, "Weather station info: ", device.info, flush=True)
            print(callStack, "MAC address of weather station: ", device.mac_address, flush=True)
        result = Iconn.execute("SELECT date FROM weather ORDER BY date DESC LIMIT 2")
        lastTimeInDb = None
        nextToLastTime = None
        for r in result:
            if lastTimeInDb is None: lastTimeInDb = r[0]
            elif nextToLastTime is None:
                nextToLastTime = r[0]
                break
        result = Iconn.execute("SELECT date FROM weather ORDER BY date LIMIT 1")
        firstTimeInDb = None
        for r in result:
            firstTimeInDb = r[0]
        timeDiff = lastTimeInDb - nextToLastTime
        nowTime = datetime.now()
        numNew = int((nowTime - lastTimeInDb) / timeDiff)
        if Verbosity >= 2:
            print(callStack, "lastTimeInDb: ", lastTimeInDb, "; nextToLastTime: ", nextToLastTime, "; timeDiff: ", timeDiff)
            print(callStack, "nowTime: ", nowTime)
        if Verbosity >= 1:
            print(callStack, "Number of new data points is: ", numNew)

        tzsavesql = "SET @oldtz=@@session.time_zone"
        tzsetUTC  = "SET @@session.time_zone='+00:00'"
        tzrestoresql = "SET @@session.time_zone=@oldtz"
        try:
            result = Iconn.execute(tzsavesql)
            result = Iconn.execute(tzsetUTC)
        except exc.DBAPIError as e:
            _ = e
            print("Caught DBAPIError exception settinmg time_zone: ", e)
            pass

        time.sleep(2)       # Wait a while for Ambient server to recover: at least 1 sec.

        wdata = device.get_data(limit=numNew+2)     # Get a couple duplicates "just in case"
        if len(wdata) > 0:
            if Verbosity >= 1:
                print(callStack, "Length, type of weather device data:", len(wdata), type(wdata), type(wdata[0]), flush=True)
            if Verbosity >= 2:
                print(callStack, "Weather device data:", wdata, flush=True)
            for dp in wdata:
                insertsql = "INSERT IGNORE INTO `"+myschema+""`.`weather` " \
                        + str(tuple(dp.keys())).replace("'", "") \
                        + " VALUES " \
                        + str(tuple(dp.values())).replace("Z","") \
                        + " ON DUPLICATE KEY UPDATE date = VALUES(date)"
                if Verbosity >= 3:
                    print(callStack, "Insert SQL: ", insertsql, flush=True)
                try:
                    Iconn.execute(insertsql)
                except exc.DBAPIError as e:
                    _ = e
                    print("Caught DBAPIError exception inserting data: ", e)
                    pass
        else:
            print(callStack, "No new weather data retrieved.")

        if (Verbosity >= 1) and (firstDate is not None) and (firstTimeInDb is not None) and (firstDate >= firstTimeInDb):
            print(callStack, "Database already has desired historical data.")
        elif (firstDate is not None) and (firstTimeInDb is not None) and (firstDate < firstTimeInDb):
            if Verbosity >= 1:
                print(callStack, "Trying to retrieve historical weather data before: ", firstTimeInDb, " back to: ", firstDate)
            time.sleep(2)       # wait for ambient serv er to recover
            wdata = device.get_data(end_date = firstTimeInDb)
            if len(wdata) > 0:
                if Verbosity >= 1:
                    print(callStack, "Length, type of weather device data:", len(wdata), type(wdata), type(wdata[0]), flush=True)
                if Verbosity >= 2:
                    print(callStack, "Weather device data:", wdata, flush=True)
                for dp in wdata:
                    insertsql = "INSERT IGNORE INTO `"+myschema+""`.`weather` " \
                            + str(tuple(dp.keys())).replace("'", "") \
                            + " VALUES " \
                            + str(tuple(dp.values())).replace("Z","") \
                            + " ON DUPLICATE KEY UPDATE date = VALUES(date)"
                    if Verbosity >= 3:
                        print(callStack, "Insert SQL: ", insertsql, flush=True)
                    try:
                        Iconn.execute(insertsql)
                    except exc.DBAPIError as e:
                        _ = e
                        print("Caught DBAPIError exception inserting data: ", e)
                        pass
            else:
                if Verbosity >= 0:
                    print(callStack, "No historical data retrieved.")

        try:
            result = Iconn.execute(tzrestoresql)
        except exc.DBAPIError as e:
            _ = e
            print("Caught DBAPIError exception restoring time zone: ", e)
            pass


    callStack.pop()


if __name__ == "__main__":
    main()
    pass
