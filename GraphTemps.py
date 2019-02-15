#!/usr/bin/env python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sqlalchemy import create_engine
import pymysql as mysql
import pymysql.err as Error
import time
import datetime
from datetime import date
from datetime import timedelta
from datetime import datetime
import os
import argparse
import sys
import configparser
import logging
import logging.config
import logging.handlers
import json

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
                logFileName = os.path.join(logPath, config_dict['handlers'][p]['filename'])
                config_dict['handlers'][p]['filename'] = logFileName
        logging.config.dictConfig(config_dict)
    except Exception as e:
        print("loading logger config from file failed.")
        print(e)
        pass

logger = logging.getLogger(__name__)
logger.info('logger name is: "%s"', logger.name)
logging.getLogger('matplotlib.axes._base').setLevel('WARNING')      # turn off matplotlib info & debug messages
logging.getLogger('matplotlib.font_manager').setLevel('WARNING')

DBConn = None
DBCursor = None
Topics = []    # default topics to subscribe
mqtt_msg_table = None
RequiredConfigParams = frozenset(('ss_ha_schema', 'rc_ha_schema', 'rc_my_schema', 'ss_my_schema', 'rc_database_host', 'rc_database_port', 'ss_database_host', 'ss_database_port', 'database_reader_user', 'database_reader_password'))

def GetConfigFilePath():
    fp = os.path.join(ProgPath, 'secrets.ini')
    if not os.path.isfile(fp):
        fp = os.environ['PrivateConfig']
        if not os.path.isfile(fp):
            logger.error('No configuration file found.')
            sys.exit(1)
    logger.info('Using configuration file at: %s', fp)
    return fp
    

#  global twoWeeksAgo, filePath
DelOldCsv = False
twoWeeksAgo = (datetime.today() - timedelta(days=14))
filePath = os.path.abspath(os.path.join(os.environ['HOME'], 'GraphingData'))
ServerTimeFromUTC = timedelta(hours=0)
ServerTimeFromUTCSec = 0
haschema = ""
myschema = ""
BeginTime = None       # Number of days to plot

    # make sure "fdata" is defined AS a dataframe; value ignored if csv data is read.
#fdata = pd.DataFrame({ 'A' : 1., 'B' : pd.Timestamp('20130102'), 'C' : pd.Series(1,index=list(range(4)),dtype='float32') })

def makeQuery(dataName, tableName, timeField='time', databaseName=None):
    global myschema

    if databaseName is None: databaseName = myschema
    query = "SELECT {timeField} AS 'Time', value AS '{dataName}' \
    FROM `{databaseName}`.`{tableName}` \
    WHERE {timeField} > '%s' \
    ORDER BY {timeField}".format(timeField=timeField, dataName=dataName, tableName=tableName, databaseName=databaseName)
    logger.debug("generated query is: %s", query)

    return query

def GetData(fileName, DBConn = None, query = None):
    """
        fileName            <string>        is the file name of a CSV file containing previously retrieved data
                                relative to global filePath.
        DBConn              <connection>    is the database connection object.
        query               <string>        is an SQL query to retrieve the data, with %s where the begin date goes.
        beginDate           <datetime>      is the DATE of the beginning of the data to retrieve in SERVER local time.
        dataTimeOffsetUTC   <timedelta>     is the amount to adjust beginDate for selecting new data.
                                Add this number to a UTC time to get a corresponding time in the DATABASE.
                                Subtract this number (of hours) from a database time to get UTC.

        1)  Function reads data from the CSV file if it exists, adjusts beginDate to the
        end of the data that was read from CSV so that the SQL query can read only data that
        was not previously read.  (But only if there is more than 20 minutes unread data.)

        2)  The query MUST have a WHERE clause like: " AND {timeField} > '%s'"
        the {timeField} is the database column that retrieves the time data.
        The beginDate is adjusted by use of dataTimeOffsetUTC so that what gets
        filled into the query is in the same time zone as the native data in the database.
        This is to simplify the computations in the WHERE clause.

        3)  The query should retrieve a "Time" field which will be used as an "index" into the
        retrieved DataFrame (in Pandas lingo).  This time data should be adjusted to be in
        the SERVER's local timezone:  daylight saving time or standard time as appropriate to
        the date/time the data is retrieved.  Glitches when transitioning to/from DST are ignored.

        4)  beginDate is a DATE value on entry; we don't worry about time zones when considering the
        beginning of data on the graph.  We use this value to prune the beginning of data
        retrieved from the CSV file.  When used to retrieve DATABASE data, it is converted to the
        same time zone as the {timeField}; not necessarily the timezone of the retrieved data -- see above.

        5)  beginDate is a "datetime" value when used to retrieve SQL data.  See paragraph 1.
        dataTimeOffsetUTC input parameter is used with global ServerTimeFromUTC to determine this value.
        beginDate from the CSV file is in SERVER local time.  Subtract ServerTimeFromUTC from CSV timestamp
        time to get equivalent UTC time.  Then add dataTimeOffsetUTC to get to DATABASE time zone.

        For example:  "creation" vaules in homeassistant database tables are stored in UTC.  The timestamp
        values from the database have ServerTimeFromUTC added to them to get SERVER local times.  For the
        WHERE clause, ServerTimeFromUTC is subtracted from the CSV time, and dataTimeOffsetUTC=0 is added.

        Another example:  Time in the FreezeProtection table in RC is a "timestamp" value, which returns
        time values in the SERVER timezone; the CSV times are appropriate.  For the WHERE clause beginDate,
        ServerTimeFromUTC=-8 is subtracted from the CSV time, and dataTimeOffsetUTC=-8 is added.

        Another example:???
    """
    global filePath
    # Pick up local variables from globals
    beginDate = BeginTime
    dataTimeOffsetUTC = ServerTimeFromUTC

    logger.debug('call args beginDate = %s dataTimeOffsetUTC = %s', beginDate, dataTimeOffsetUTC)
    theFile = os.path.join(filePath, fileName)
    logger.info('theFile: %s', theFile)
    CSVdataRead = False     # flag is true if we read csv data
    if  os.path.exists(theFile):
        if DelOldCsv:
            os.remove(theFile)
            logger.info('CSV file deleted.')
        else:
            fdata = pd.read_csv(theFile, index_col=0, parse_dates=True)
            logger.debug('Num Points from CSV = %s', fdata.size)
            if (fdata.size <= 0):
                logger.info("CSV file exists but has no data.") 
            elif (beginDate is not None) and (fdata.index[0] > beginDate):
                logger.debug("CSV data all more recent than desired data; ignore it.")
            else:
                beginDate = fdata.index[-1]
                logger.debug('Last CSV time = new beginDate = %s', beginDate)
                logger.debug('CSVdata tail:\n%s', fdata.tail())
                logger.debug('CSVdata dtypes:\n%s', fdata.dtypes)
                logger.debug('CSVdata columns:\n%s', fdata.columns)
                logger.debug('CSVdata index:\n%s', fdata.index)
                CSVdataRead = True
    else:
        logger.debug('CSV file does not exist.')
        pass
    logger.debug('beginDate after CSV modified for SQL = %s', beginDate)
    logger.debug("Comparing: now UTC time: %s and UTC data time: %s", datetime.utcnow(), (beginDate - dataTimeOffsetUTC))
    if (not CSVdataRead) or (datetime.utcnow() - beginDate + dataTimeOffsetUTC) > timedelta(minutes=20) and DBConn and query:
        myQuery = query%beginDate.isoformat()
        logger.info('SQL query: %s', myQuery)
        data = pd.read_sql_query(myQuery, DBConn, index_col='Time')
        if data.index.size != 0:
                # Have SQL data
            logger.debug('Num Points from SQL = %s', data.index.size)
            logger.debug('sql data head:\n%s', data.head())
            logger.debug('sql data tail:\n%s', data.tail())
            logger.debug('sql data dtypes:\n%s', data.dtypes)
            logger.debug('sql data columns:\n%s', data.columns)
            logger.debug('sql data index:\n%s', data.index)
            if CSVdataRead:
                #  Have SQL data and have CSV data, put them together
                data =  fdata.append(data)
                logger.debug('appended data tail:\n%s', data.tail())
                logger.debug('appended data dtypes:\n%s', data.dtypes)
                logger.debug('appended data columns:\n%s', data.columns)
                logger.debug('appended data index:\n%s', data.index)
                pass
            else:
                logger.debug('No CSV data to which to append SQL data.')
                pass    # No CSV data in fdata; SQL data in data
        else:
            # No SQL data
            logger.debug('No Sql data read.')
            if CSVdataRead:
                # Have CSV data, no SQL data; copy CSV data to output dataFrame
                data = fdata
            else:
                logger.debug('No CSV data AND no SQL data!!')
                pass    # No CSV data, no SQL data:  punt??
            pass
    else:
        if DBConn and query:
            logger.info("CSV data is recent enough; don't query database. ")
            logger.debug("now %s beginDate %s diff %s", datetime.utcnow(), beginDate, (datetime.utcnow() - beginDate))
        else:
            logger.debug('No database parameters defined; no SQL data.')
        data = fdata
        pass

    # Only save two weeks of data in the CSV file
    data.query('index > "%s"'% twoWeeksAgo.isoformat()).to_csv(theFile, index='Time')

    slicer = 'index > "%s"'%(beginDate + dataTimeOffsetUTC).isoformat()     # pandas "query" to remove old data FROM csv data
    logger.info('slicer = %s', slicer)
    return data.query(slicer)       # return data from beginDate to  present

def ShowRCPower(DBConn):
    global filePath, ServerTimeFromUTC

    ###############################  POWER  ############################################
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Power')
    ax1.set_ylabel('Watts')
    maxTime = 0             # maxTime is used to extend the LR Light data to the end of other data
    plt.set_cmap('Dark2')

    logger.info("          ----------  HOUSE POWER ----------")
    query = "SELECT {timeField} AS 'Time', \
        HousePowerW AS 'House' \
        FROM `{schema}`.`MeterData` WHERE \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info("House Power SQL: %s", query)
    data = GetData('HousePower.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
    else:
        logger.info("No data to plot")

    logger.info("          ----------  HUMIDIFIER POWER ----------")
    query = makeQuery(timeField='time', dataName='Humidifier', tableName='humidifier_power')
    logger.info("Humidifier power SQL: %s", query)
    data = GetData('HumidifierPower.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
    else:
        logger.info("No data to plot")

    logger.info("          ----------  FRIDGE POWER ----------")
    query = makeQuery(timeField='time', dataName='Refrigerator', tableName='fridge_power')
    logger.info("Fridge Power SQL: %s", query)
    data = GetData('FridgePower.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
    else:
        logger.info("No data to plot")

    logger.info("          ----------  A/C POWER ----------")
    query = makeQuery(timeField='time', dataName='A/C Power', tableName='ac_power')
    logger.info("AC Power SQL: %s", query)
    data = GetData('ACPower.csv', DBConn, query)
    if len(data) > 0:
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  LR LIGHT POWER ----------")
    query = makeQuery(timeField='time', dataName='LR Light', tableName='lrlight_power')
    logger.info("LR Light SQL: %s", query)
    data = GetData('LRLight.csv', DBConn, query)
    if len(data) > 0:
        if (maxTime == 0) or (maxTime < data.index.max()): maxTime = data.index.max()
        data = pd.concat([data, pd.DataFrame({'LR Light': [data['LR Light'][-1]]}, index=[maxTime])])
        data.plot(ax=ax1, drawstyle="steps-post")
    else:
        logger.info("No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)


def ShowRCLaundry(DBConn):
    global filePath
    #############    Laundry Trap    #########

            # Supply default beginDate from CURRENT value of twoWeeksAgo
    fig = plt.figure(figsize=[15, 5])   #  Define a figure and set its size in inches.
    ax1 = fig.add_subplot(1, 1, 1)      #  Get reference to axes for labeling
    ax1.set_ylabel('°F')
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Laundry Trap')

    logger.info("          ----------  LAUNDRY TRAP ----------")
    query = "SELECT {timeField} AS 'Time', \
        TrapTemperature*9/5+32 AS 'Trap', \
        HotWaterValveTemp*9/5+32 AS 'HW',\
        ColdWaterValveTemp*9/5+32 AS 'CW', \
        (1-HotWaterValveOFF)*10+20 AS 'HW Valve', \
        (1-ColdWaterValveOFF)*10+15 AS 'CW Valve' \
        FROM `{schema}`.`FreezeProtection` \
        WHERE {timeField} > '%s' \
        ORDER BY {timeField}".format(timeField='CollectionTime', schema=myschema)
    logger.info('Laundry query:\n%s', query)
    data = GetData('LaundryTrap.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  OUTSIDE  ----------")
    query = "SELECT {timeField} AS 'Time', OutsideTemp AS 'Outside' \
        FROM `{schema}`.`weather` WHERE {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info("Out Temp SQL: %s", query)
    data = GetData('RcOutTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)


def ShowRCSolar(DBConn):
    global filePath

    ###############################  Solar Energy  ############################################
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    #  Setup the figure with two y axes
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Solar')
    ax2 = ax1.twinx()  # instantiate a second axes that shares the same x-axis
    plt.set_cmap('Dark2')

    logger.info("          ----------  NORTH SOLAR ----------")
    query = "SELECT {timeField} AS 'Time', OutWattsNow AS 'North Array' \
        FROM `{schema}`.`SolarEnergy` WHERE Name = 'North Array' AND \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info('North Arrray query: %s', query)
    data = GetData('NorthArray.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")
    ax1.set_ylabel('Watts')  # we already handled the x-label with ax1
    ax1.legend(loc=2)

    logger.info("          ----------  SOUTH SOLAR ----------")
    query = "SELECT {timeField} AS 'Time', OutWattsNow AS 'South Array' \
        FROM `{schema}`.`SolarEnergy` WHERE Name = 'South Array' AND \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info('South Arrray query: %s', query)
    data = GetData('SouthArray.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")
    ax1.set_ylabel('Watts')  # we already handled the x-label with ax1

    logger.info("          ----------  SOLAR RADIATION ----------")
    query = "SELECT {timeField} AS 'Time', SolarRad FROM `{schema}`.`Weather` \
        WHERE {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info('SolarRad query: %s', query)
    data = GetData('SolarRad.csv', DBConn, query)
    ax2.set_ylabel('W/m^2', color='tab:red')  # we already handled the x-label with ax1
    ax2.tick_params('y', colors='tab:red')
    if len(data) > 0:
        data.plot(ax=ax2, color='tab:red')
    else:
        logger.info("No data to plot")
    ax2.legend(loc=5)
    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)


def ShowRCWater(DBConn):
    global filePath

    ###############################  Water  ############################################
            # Supply default beginDate from CURRENT value of twoWeeksAgo
    #  Setup the figure with two y axes
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Water')
    ax2 = ax1.twinx()  # instantiate a second axes that shares the same x-axis
    plt.set_cmap('Dark2')

    #
    #   Two queries since plotted on different axes.
    #
    logger.info("          ----------  GALLONS PER MIN   ----------")
    query = "SELECT {timeField} AS 'Time', \
        GPM AS 'Gallons/min' \
        FROM `{schema}`.`MeterData` WHERE \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info('GPM query: %s', query)
    data = GetData('GPM.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")
    ax1.set_ylabel('Gallons Per Minute')  # we already handled the x-label with ax1

    logger.info("          ----------  WATER SYS POWER   ----------")
    query = "SELECT {timeField} AS 'Time', \
        AvgWaterPowerW AS 'Well Power' \
        FROM `{schema}`.`MeterData` WHERE \
        {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info('WellPower query: %s', query)
    data = GetData('WellPower.csv', DBConn, query)
    ax2.set_ylabel('Watts', color='tab:red')  # we already handled the x-label with ax1
    ax2.tick_params('y', colors='tab:red')
    if len(data) > 0:
        data.plot(ax=ax2, color='tab:red')
    else:
        logger.info("No data to plot")
    ax2.legend(loc=5)
    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)


def ShowRCTemps(DBConn):
    global filePath

            # Supply default beginDate from CURRENT value of twoWeeksAgo
    ###############################  Temperatures  ############################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Temperatures')
    ax1.set_ylabel('°F')
    plt.set_cmap('Dark2')

    logger.info("          ----------  OUTSIDE / INSIDE TEMP  ----------")
    query = "SELECT {timeField} AS 'Time', OutsideTemp, InsideTemp AS 'Computer' \
        FROM `{schema}`.`weather` WHERE {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info("Out, In Temp SQL: %s", query)
    data = GetData('RcWxTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  THERMOSTAT TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Thermostat', tableName='thermostat_temp')
    logger.info("Thermostat temp SQL: %s", query)
    data = GetData('ThermostatTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  DINING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Dining', tableName='dining_temp')
    logger.info("Dining temp SQL: %s", query)
    data = GetData('DiningTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  GUEST TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Guest', tableName='guest_temp')
    logger.info("Guest temp SQL: %s", query)
    data = GetData('GuestTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  KITCHEN TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_temp')
    logger.info("Kitchen temp SQL: %s", query)
    data = GetData('KitchenTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  MASTER TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_temp')
    logger.info("Master temp SQL: %s", query)
    data = GetData('MasterTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  LIVING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_temp')
    logger.info("Living temp SQL: %s", query)
    data = GetData('LivingTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)


def ShowRCHums(DBConn):
    global filePath

    ###############################  Humidities  ############################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Humidities')
    ax1.set_ylabel('% HUMIDITY')
    plt.set_cmap('Dark2')

    logger.info("          ----------  OUTSIDE / INSIDE HUMIDITY ----------")
    query = "SELECT {timeField} AS 'Time', OutsideHumidity AS 'Outside', InsideHumidity AS 'Computer' \
        FROM `{schema}`.`weather` WHERE {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info("Out, In Hum SQL: %s", query)
    data = GetData('RcWxHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  THERMOSTAT HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Thermostat', tableName='thermostat_hum')
    logger.info("Thermostat Hum SQL: %s", query)
    data = GetData('ThermostatHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  DINING HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Dining', tableName='dining_hum')
    logger.info("Dining Hum SQL: %s", query)
    data = GetData('DiningHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  GUEST HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Guest', tableName='guest_hum')
    logger.info("Guest Hum SQL: %s", query)
    data = GetData('GuestHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  KITCHEN HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_hum')
    logger.info("Kitchen Hum SQL: %s", query)
    data = GetData('KitchenHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  MASTER HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_hum')
    logger.info("Master Hum SQL: %s", query)
    data = GetData('MasterHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  LIVING HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_hum')
    logger.info("Living Hum SQL: %s", query)
    data = GetData('LivingHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)


def ShowRCHeaters(DBConn):
    global filePath

    ###############################  HEATERS  ############################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Ridgecrest Heaters')
    ax1.set_ylabel('°F Temperature')
    ax2 = ax1.twinx()  # instantiate a second axes that shares the same x-axis
    ax2.set_ylabel('Watts')  # we already handled the x-label with ax1
    # ax2.tick_params('y')
    plt.set_cmap('Dark2')

    logger.info("          ----------  COMPUTER TEMP ----------")
    query = "SELECT {timeField} AS 'Time', InsideTemp AS 'Computer' \
        FROM `{schema}`.`weather` WHERE {timeField} > '%s' ORDER BY {timeField}".format(timeField='Time', schema=myschema)
    logger.info("Computer Temp SQL: %s", query)
    data = GetData('ComputerTemp.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  DINING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Dining', tableName='dining_temp')
    logger.info("Dining temp SQL: %s", query)
    data = GetData('DiningTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  GUEST TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Guest', tableName='guest_temp')
    logger.info("Guest temp SQL: %s", query)
    data = GetData('GuestTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  KITCHEN TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_temp')
    logger.info("Kitchen temp SQL: %s", query)
    data = GetData('KitchenTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  MASTER TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_temp')
    logger.info("Master temp SQL: %s", query)
    data = GetData('MasterTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  LIVING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_temp')
    logger.info("Living temp SQL: %s", query)
    data = GetData('LivingTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  COMPUTER HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Computer', tableName='computer_heater_power')
    logger.info("Dining H Power SQL: %s", query)
    data = GetData('ComputerHeaterWatts.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  DINING HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Dining', tableName='dining_heater_power')
    logger.info("Dining H Power SQL: %s", query)
    data = GetData('DiningHeaterWatts.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  GUEST HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Guest', tableName='guest_heater_power')
    logger.info("Guest H Power SQL: %s", query)
    data = GetData('GuestHeaterWatts.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  KITCHEN HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_heater_power')
    logger.info("Kitchen H Power SQL: %s", query)
    data = GetData('KitchenHeaterWatts.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  MASTER HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_heater_power')
    logger.info("Master H Power SQL: %s", query)
    data = GetData('MasterHeaterWatts.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  LIVING HEATER POWER  ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_heater_power')
    logger.info("Living H Power SQL: %s", query)
    data = GetData('LivingHeaterWatts.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax2)
    else:
        logger.info("No data to plot")

    # ax2.legend()
    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)


def ShowSSFurnace(DBConn):
    global filePath
    ###############################  SS Furnace  ############################################
    fig = plt.figure(figsize=[15, 5])   #  Define a figure and set its size in inches.
    ax1 = fig.add_subplot(1, 1, 1)      #  Get reference to axes for labeling
  # ax1.set_ylabel('°F')
    ax1.set_xlabel('Date/time')
    ax1.set_title('Steamboat Furnace')


    logger.info("          ----------  STEAMBOAT FURNACE ----------")
    query = "SELECT {timeField} AS 'Time', \
    round(json_value(message, '$.Temperature'), 1) AS 'Temp', \
    round(json_value(message, '$.Humidity'), 1) AS 'Humidity', \
    (json_value(message, '$.Burner') = 'ON')*20+20 AS 'Furnace', \
    (json_value(message, '$.MotionDetected') = 'ON')*10+15 AS 'Motion' \
    FROM `{schema}`.`mqttmessages` WHERE topic='dc4f220da32f/data' \
    AND {timeField}  > '%s' \
    AND {timeField}  < now(6) /* eliminate spurious records with times too late */ \
    AND json_value(message, '$.Temperature') < 150 \
    AND json_value(message, '$.Humidity') < 110 \
    ORDER BY {timeField}".format(timeField='RecTime', schema = myschema)
    logger.debug(' SQL query:\n%s', query)
    data = GetData('SSFurnace.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
        ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
        plt.show()
        plt.close(fig)
    else:
        logger.warning("No data to plot for Steamboat Furnace")

def ShowSSTemps(DBConn):
    global filePath
    ###############################  SS Temperatures  ##########################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Steamboat Temperatures')
    ax1.set_ylabel('°F')

    logger.info("          ----------  OUTSIDE/INSIDE TEMPS ----------")
    query = "SELECT {timeField} AS 'Time', \
    tempf AS 'Outside', \
    tempinf AS 'Hallway' \
    FROM `{schema}`.`weather` WHERE {timeField}  > '%s' \
    ORDER BY {timeField}".format(timeField='date', schema = myschema)
    logger.debug(' SQL query:\n%s', query)
    data = GetData('SSWeatherTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  MASTER TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_temp', databaseName=myschema)
    logger.info("Master temp SQL: %s", query)
    data = GetData('SSMasterTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  LIVING TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_temp', databaseName=myschema)
    logger.info("Living temp SQL: %s", query)
    data = GetData('SSLivingTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  COMPUTER TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Computer', tableName='computer_temp', databaseName=myschema)
    logger.info("Computer temp SQL: %s", query)
    data = GetData('SSComputerTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  KITCHEN TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_temp', databaseName=myschema)
    logger.info("Kitchen temp SQL: %s", query)
    data = GetData('SSKitchenTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  MUD TEMP  ----------")
    query = makeQuery(timeField='time', dataName='Mud', tableName='mud_temp', databaseName=myschema)
    logger.info("Mud temp SQL: %s", query)
    data = GetData('SSMudTemps.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)


def ShowSSHums(DBConn):
    global filePath
    ###############################  SS Humidities    ##########################################
    fig = plt.figure(figsize=[15, 5])
    ax1 = fig.add_subplot(1, 1, 1)
    ax1.set_xlabel('Date/time')
    ax1.set_title('Steamboat Humidities')
    ax1.set_ylabel('% HUMIDITY')

    logger.info("          ----------  OUTSIDE/INSIDE HUMIDITIES ----------")
    query = "SELECT {timeField} AS 'Time', \
    humidity AS 'Outside', \
    humidityin AS 'Hallway' \
    FROM `{schema}`.`weather` WHERE {timeField}  > '%s' \
    ORDER BY {timeField}".format(timeField='date', schema = myschema)
    logger.info(' SQL query:\n%s', query)
    data = GetData('SSWeatherHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  MASTER HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Master', tableName='master_hum', databaseName=myschema)
    logger.info("Master Hum SQL: %s", query)
    data = GetData('SSMasterHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  LIVING HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Living', tableName='living_hum', databaseName=myschema)
    logger.info("Living Hum SQL: %s", query)
    data = GetData('SSLivingHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  COMPUTER HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Computer', tableName='computer_hum', databaseName=myschema)
    logger.info("Computer Hum SQL: %s", query)
    data = GetData('SSComputerHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  KITCHEN HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Kitchen', tableName='kitchen_hum', databaseName=myschema)
    logger.info("Kitchen Hum SQL: %s", query)
    data = GetData('SSKitchenHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    logger.info("          ----------  MUD HUMIDITY ----------")
    query = makeQuery(timeField='time', dataName='Mud', tableName='mud_hum', databaseName=myschema)
    logger.info("Mud Hum SQL: %s", query)
    data = GetData('SSMudHums.csv', DBConn, query)
    if len(data) > 0:
        data.plot(ax=ax1)
    else:
        logger.info("No data to plot")

    ax1.set_xlim(left=BeginTime, right=(datetime.utcnow() + ServerTimeFromUTC))
    plt.show()
    plt.close(fig)


def main():
    global filePath, ServerTimeFromUTC, twoWeeksAgo, ServerTimeFromUTCSec, DelOldCsv, haschema, myschema
    global BeginTime

    RCGraphs = {'solar', 'laundry', 'hums', 'temps', 'water', 'power', 'heaters'}
    SSGraphs = {'Furnace', 'Temps', 'Hums'}
    parser = argparse.ArgumentParser(description = 'Display graphs of home parameters.\nDefaults to show all.')
    parser.add_argument("-d", "--days", dest="days", action="store", help="Number of days of data to plot", default=14)
    parser.add_argument("-l", "--laundry", dest="laundry", action="store_true", help="Show Ridgecrest Laundry Trap graph.")
    parser.add_argument("-s", "--solar", dest="solar", action="store_true", help="Show Ridgecrest Solar graph.")
    parser.add_argument("-u", "--humidities", dest="hums", action="store_true", help="Show Ridgecrest Humidities graph.")
    parser.add_argument("-t", "--temperatures", dest="temps", action="store_true", help="Show Ridgecrest Temperatures graph.")
    parser.add_argument("-w", "--water", dest="water", action="store_true", help="Show Ridgecrest Water graph.")
    parser.add_argument("-e", "--heaters", dest="heaters", action="store_true", help="Show Ridgecrest Heaters graph.")
    parser.add_argument("-p", "--power", dest="power", action="store_true", help="Show Ridgecrest Power graph.")
    parser.add_argument("-F", "--SSFurnace", dest="Furnace", action="store_true", help="Show Steamboat Furnace graph.")
    parser.add_argument("-H", "--SSHumidities", dest="Hums", action="store_true", help="Show Steamboat Humidities graph.")
    parser.add_argument("-T", "--SSTemperatures", dest="Temps", action="store_true", help="Show Steamboat Temperatures graph.")
    parser.add_argument("-v", "--verbosity", dest="verbosity", action="count", help="increase output verbosity", default=0)
    parser.add_argument("--DeleteOldCSVData", dest="DeleteOld", action="store_true", help="Delete any existing CSV data for selected graphs before retrieving new.")
    args = parser.parse_args()
    Verbosity = args.verbosity
    DelOldCsv = args.DeleteOld
    numDays = float(args.days)

    desired_plots = {k for k, v in vars(args).items() if v}
    desired_plots.discard('verbosity')      # verbosity not a plotting item
    desired_plots.discard('DeleteOld')      # DeleteOldCSVData not a plotting item
    desired_plots.discard('days')      # number of days is not a plotting item

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

    configGraphs = []
    if config.has_option(cfgSection, 'default_rc_graphs'):
        configGraphs.extend(cfg['default_rc_graphs'].split())
        logger.debug('configGraphs for rc is %s', configGraphs)
    if config.has_option(cfgSection, 'default_ss_graphs'):
        configGraphs.extend(cfg['default_ss_graphs'].split())
        logger.debug('configGraphs for rc and ss is %s', configGraphs)
    if len(desired_plots) == 0 and len(configGraphs) > 0:     # no options given, provide a default set from config.
        desired_plots = set(configGraphs)        # config graphs

    if len(desired_plots) == 0:     # no options given, and no config graphs, provide a default set.
        desired_plots = SSGraphs.union(RCGraphs)        # all graphs
        logger.debug('No plots specified on command lind or config file; plot all known.')
    logger.info('Desired plots set is: %s', desired_plots)
    logger.info('Command line contains RC graphs: %s', not RCGraphs.isdisjoint(desired_plots))
    logger.info('Command line contains SS graphs: %s', not SSGraphs.isdisjoint(desired_plots))


    if  not RCGraphs.isdisjoint(desired_plots):
        user = cfg['database_reader_user']
        pwd  = cfg['database_reader_password']
        host = cfg['rc_database_host']
        port = cfg['rc_database_port']
        haschema = cfg['rc_ha_schema']
        myschema = cfg['rc_my_schema']
        logger.info("RC user %s", user)
        logger.info("RC pwd %s", pwd)
        logger.info("RC host %s", host)
        logger.info("RC port %s", port)
        logger.info("RC haschema %s", haschema)
        logger.info("RC myschema %s", myschema)

        connstr = 'mysql+pymysql://{user}:{pwd}@{host}:{port}/{schema}'.format(user=user, pwd=pwd, host=host, port=port, schema=haschema)
        logger.debug("RC database connection string: %s", connstr)
        Eng = create_engine(connstr, echo = True if Verbosity>=2 else False, logging_name = logger.name)
        logger.debug(Eng)
        with Eng.connect() as conn, conn.begin():
            result = conn.execute("select timestampdiff(hour, utc_timestamp(), now());")
            for row in result:
                ServerTimeFromUTC = timedelta(hours=row[0])
                ServerTimeFromUTCSec = ServerTimeFromUTC.days*86400+ServerTimeFromUTC.seconds
            twoWeeksAgo = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=14))
            BeginTime = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=numDays))
            logger.debug("RC Server time offset from UTC: %s", ServerTimeFromUTC)
            logger.debug("RC Server time offset from UTC (seconds): %s", ServerTimeFromUTCSec)
            logger.debug("RC twoWeeksAgo: %s", twoWeeksAgo)
            if 'laundry'    in desired_plots:   ShowRCLaundry(conn)
            if 'solar'      in desired_plots:   ShowRCSolar(conn)
            if 'temps'      in desired_plots:   ShowRCTemps(conn)
            if 'hums'       in desired_plots:   ShowRCHums(conn)
            if 'heaters'    in desired_plots:   ShowRCHeaters(conn)
            if 'water'      in desired_plots:   ShowRCWater(conn)
            if 'power'      in desired_plots:   ShowRCPower(conn)

    if  not SSGraphs.isdisjoint(desired_plots):
        user = cfg['database_reader_user']
        pwd  = cfg['database_reader_password']
        host = cfg['ss_database_host']
        port = cfg['ss_database_port']
        haschema = cfg['ss_ha_schema']
        myschema = cfg['ss_my_schema']
        logger.info("SS user %s", user)
        logger.info("SS pwd %s", pwd)
        logger.info("SS host %s", host)
        logger.info("SS port %s", port)
        logger.info("SS haschema %s", haschema)
        logger.info("SS myschema %s", myschema)

        connstr = 'mysql+pymysql://{user}:{pwd}@{host}:{port}/{schema}'.format(user=user, pwd=pwd, host=host, port=port, schema=haschema)
        logger.debug("SS database connection string: %s", connstr)
        Eng = create_engine(connstr, echo = True if Verbosity>=2 else False, logging_name = logger.name)
        logger.debug(Eng)
        with Eng.connect() as conn, conn.begin():
            result = conn.execute("select timestampdiff(hour, utc_timestamp(), now());")
            for row in result:
                ServerTimeFromUTC = timedelta(hours=row[0])
                ServerTimeFromUTCSec = ServerTimeFromUTC.days*86400+ServerTimeFromUTC.seconds
            twoWeeksAgo = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=14))
            BeginTime = (datetime.utcnow() + ServerTimeFromUTC - timedelta(days=numDays))
            logger.debug("SS Server time offset from UTC: %s", ServerTimeFromUTC)
            logger.debug("SS Server time offset from UTC (seconds): %s", ServerTimeFromUTCSec)
            logger.debug("SS twoWeeksAgo: %s", twoWeeksAgo)
            if 'Furnace' in desired_plots:      ShowSSFurnace(conn)
            if 'Temps' in desired_plots:        ShowSSTemps(conn)
            if 'Hums' in desired_plots:         ShowSSHums(conn)



if __name__ == "__main__":
    main()
    pass
