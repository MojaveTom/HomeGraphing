#!/usr/bin/env python3
'''Program plots data from home databases.

Run with -h or --help to see command line options.
'''
import pandas as pd                 #   https://pandas.pydata.org/pandas-docs/stable/
import numpy as np                  #   https://numpy.org/doc/stable/
from bokeh.layouts import gridplot  #   https://docs.bokeh.org/en/latest/docs/user_guide/layout.html
from bokeh.plotting import figure, show, output_file    #   https://docs.bokeh.org/en/latest/docs/user_guide/plotting.html
from bokeh.models import ColumnDataSource, HoverTool, Legend, LegendItem    #   https://docs.bokeh.org/en/latest/docs/dev_guide/models.html
from bokeh.models import Range1d, DataRange1d, LinearAxis
from bokeh.resources import Resources       #   https://docs.bokeh.org/en/latest/docs/reference/resources.html#module-bokeh.resources
from bokeh.embed import file_html   #   https://docs.bokeh.org/en/latest/docs/reference/embed.html#module-bokeh.embed
from bokeh.util.browser import view #   https://docs.bokeh.org/en/latest/docs/reference/util.html#module-bokeh.util.browser
from bokeh.models.formatters import DatetimeTickFormatter   #   https://docs.bokeh.org/en/latest/docs/reference/models/formatters.html#module-bokeh.models.formatters
# from bokeh.models.tickers import DatetimeTicker

from myPalette import Palette       #   classes defined in this directory
import myPalette
from GraphDefinitions import GetGraphDefs

from datetime import datetime as dt #   https://docs.python.org/3/library/datetime.html#datetime-objects
from datetime import timezone       #   https://docs.python.org/3/library/datetime.html#date-objects
from datetime import time as dtime  #   https://docs.python.org/3/library/datetime.html#time-objects
from datetime import timedelta      #   https://docs.python.org/3/library/datetime.html#timedelta-objects
import os               #   https://docs.python.org/3/library/os.html
import sys              #   https://docs.python.org/3/library/sys.html
import argparse         #   https://docs.python.org/3/library/argparse.html
import configparser     #   https://docs.python.org/3/library/configparser.html
import logging          #   https://docs.python.org/3/library/logging.html
import logging.config   #   https://docs.python.org/3/library/logging.config.html
import logging.handlers #   https://docs.python.org/3/library/logging.handlers.html
import json             #   https://docs.python.org/3/library/json.html
import toml             #   https://github.com/uiri/toml    https://github.com/toml-lang/toml
import paho.mqtt.client as mqtt     #   https://www.eclipse.org/paho/clients/python/docs/
import paho.mqtt.publish as publish

from sqlalchemy import create_engine    #   https://docs.sqlalchemy.org/en/13/  https://docs.sqlalchemy.org/en/13/core/engines.html#sqlalchemy.create_engine
# import pymysql as mysql             #   https://pymysql.readthedocs.io/en/latest/
# import pymysql.err as Error

# comment json strips python and "//" comments form json before applying json.load routines.
# import commentjson      #   https://github.com/vaidik/commentjson       https://commentjson.readthedocs.io/en/latest/
# Lark is used by commentjson
# import lark             #   https://github.com/lark-parser/lark    https://lark-parser.readthedocs.io/en/latest/
import threading          #   https://docs.python.org/3/library/threading.html

import serial             #   https://pythonhosted.org/pyserial/
# from serial.threaded import *

from prodict import Prodict             #   https://github.com/ramazanpolat/prodict
from progparams.ProgramParametersDefinitions import MakeParams
from progparams.GetLoggingDict import GetLoggingDict, setConsoleLoggingLevel, setLogFileLoggingLevel, getConsoleLoggingLevel, getLogFileLoggingLevel

ProgName, ext = os.path.splitext(os.path.basename(sys.argv[0]))
ProgPath = os.path.dirname(os.path.realpath(sys.argv[0]))

##############Logging Settings##############
config_dict = GetLoggingDict(ProgName, ProgPath)
logging.config.dictConfig(config_dict)

logger = logging.getLogger(__name__)
console = logger

debug = logger.debug
info = logger.info
critical = logger.critical

helperFunctionLoggingLevel = logging.WARNING

#########################################
PP = Prodict()

DBConn = None
DBCursor = None
Topics = []    # default topics to subscribe
mqtt_msg_table = None
RequiredConfigParams = frozenset((
    'ss_ha_schema'
  , 'ss_my_schema'
  , 'ss_database_host'
  , 'ss_database_port'
  , 'rc_ha_schema'
  , 'rc_my_schema'
  , 'rc_database_host'
  , 'rc_database_port'
  , 'database_reader_user'
  , 'database_reader_password'
))

CsvFilesPath = os.path.abspath(os.path.expandvars('$HOME/GraphingData'))
if not os.path.isdir(CsvFilesPath):
    os.makedirs(CsvFilesPath, exist_ok=True)

#  global twoWeeksAgo, CsvFilesPath
DelOldCsv = False
LocalDataOnly = False
SaveCSVData = True  # Flags GetData function to save back to the CSV data file.
BeginTime = None       # Number of days to plot
DBHostDict = dict()
DatabaseReadDelta = 20

def GetData(fileName, query = None, dataTimeOffsetUTC = None, hostParams = dict()):
    """
        fileName            <string>        is the file name of a CSV file containing previously retrieved data
                                relative to global CsvFilesPath.
        DBConn              <connection>    is the database connection object.
        query               <string>        is an SQL query to retrieve the data, with {BeginDate} where the begin date goes.
        dataTimeOffsetUTC   <timedelta>     is the amount to adjust beginDate for selecting new data.
                                Add this number to a UTC time to get a corresponding time in the DATABASE.
                                Subtract this number (of hours) from a database time to get UTC.

        1)  Function reads data from the CSV file if it exists, adjusts beginDate to the
        end of the data that was read from CSV so that the SQL query can read only data that
        was not previously read.  (But only if there is more than DatabaseReadDelta minutes unread data.)

        2)  The query MUST have a WHERE clause like: " AND {timeField} > '{BeginDate}'"
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

        beginDate           <datetime>      is the DATE of the beginning of the data to retrieve in SERVER local time.
    """
    prevLogLevel = logger.getEffectiveLevel()
    # logger.setLevel('WARNING')

    if (len(hostParams) == 0) or (dataTimeOffsetUTC is None) or LocalDataOnly: # no host params, don't try to do database stuff
        logger.warning('hostParams dict is empty, or no dataTimeOffsetUTC given.  Do not access database.')
        query = None

    #  What to do if hostParams is empty??????????????? (Shouldn't happen)
    beginDate = hostParams['BeginTime']
    twoWeeksAgo = hostParams['twoWeeksAgo']
    # use these commented out lines if the DBConn doesn't survive being in the hostParams dict.
    # DBConn = hostParams['DBEngine'].connect()
    # DBConn.begin()
    DBConn = hostParams['conn']

    slicer = 'index > "%s"'%(beginDate + dataTimeOffsetUTC).isoformat()     # pandas "query" to remove old data FROM csv data
    logger.info('slicer = %s', slicer)

    SQLbeginDate = beginDate        # initial value; changed later if CSV data read

    logger.debug('call args -- fileName: %s, DBConn: %s, query: %s', fileName, DBConn, query)
    logger.debug('beginDate = %s dataTimeOffsetUTC = %s', beginDate, dataTimeOffsetUTC)
    theFile = os.path.join(CsvFilesPath, fileName)
    logger.info('theFile: %s', theFile)
    CSVdataRead = False     # flag is true if we read csv data
    if  os.path.exists(theFile):
        if DelOldCsv:
            os.remove(theFile)
            logger.info('CSV file deleted.')
            fdata = None
        else:
            fdata = pd.read_csv(theFile, index_col=0, parse_dates=True)
            logger.debug('Num Points from CSV = %s', fdata.size)
            if (fdata.size <= 0):
                logger.info("CSV file exists but has no data.")
                fdata = None
            elif (beginDate is not None) and (fdata.index[0] > beginDate):
                logger.debug("CSV data all more recent than desired data; ignore it.")
                fdata = None
            else:
                SQLbeginDate = fdata.index[-1]
                logger.debug('Last CSV time = new beginDate = %s', beginDate)
                logger.debug('CSVdata tail:\n%s', fdata.tail())
                logger.debug('CSVdata dtypes:\n%s', fdata.dtypes)
                logger.debug('CSVdata columns:\n%s', fdata.columns)
                logger.debug('CSVdata index:\n%s', fdata.index)
                CSVdataRead = True
    else:
        logger.warning('CSV file "%s" does not exist.'%theFile)
        fdata = None
        pass
    logger.debug('SQLbeginDate after CSV modified for SQL = %s', SQLbeginDate)
    logger.debug("Comparing: now UTC time: %s and UTC data time: %s", dt.utcnow(), (SQLbeginDate - dataTimeOffsetUTC))
    if ((not CSVdataRead) or (dt.utcnow() - SQLbeginDate + dataTimeOffsetUTC) > timedelta(minutes=DatabaseReadDelta)) and DBConn and query:
        logger.debug('SQLbeginDate for creating SQL query %s', SQLbeginDate)
        myQuery = query.format(BeginDate=SQLbeginDate.isoformat())
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
            logger.debug("now %s SQLbeginDate %s diff %s", dt.utcnow(), SQLbeginDate, (dt.utcnow() - SQLbeginDate))
        elif LocalDataOnly:
            logger.debug('Using local data only; no database data desired.  No SQL data.')
        else:
            logger.debug('No database parameters defined; no SQL data.')
        data = fdata
        pass

    if data is None:
        logger.setLevel(prevLogLevel)
        return data

    # Only save two weeks of data in the CSV file
    if SaveCSVData: data.query('index > "%s"'% twoWeeksAgo.isoformat()).to_csv(theFile, index='Time')

    logger.setLevel(prevLogLevel)
    return data.query(slicer)       # return data from beginDate to  present

def ShowGraph(graphDict):

    if not graphDict['ShowGraph']:
        logger.warning('%s is not shown.', graphDict['GraphTitle'])
        return

    if (len(graphDict['Yaxes']) <= 0) or (len(graphDict['items']) <= 0):
        logger.debug('No axes or no lines defined for graph "%s"', graphDict['GraphTitle'])
        return

    if graphDict['DBHost'] not in DBHostDict.keys():
        logger.warning('Unknown database host "%s" for plot "%s"' % (graphDict['DBHost'], graphDict['GraphTitle']))
        return

    hostItem = DBHostDict[graphDict['DBHost']]

    # Signal that we want to reference local files for html output.
    res = Resources(mode='absolute')

    # output_file(graphDict["outputFile"], title=graphDict['GraphTitle'])

    plot = figure(title=graphDict['GraphTitle']
            , tools="pan,wheel_zoom,box_zoom,reset,save,box_select"
            , x_axis_type='datetime'
            , plot_width=1600, plot_height=800
            , active_drag="box_zoom"
            , active_scroll = "wheel_zoom")
    plot.title.align = "center"
    plot.title.text_font_size = "25px"
    plot.xaxis.axis_label = graphDict['XaxisTitle']
    # plot.xaxis.ticker = DatetimeTicker(num_minor_ticks = 4)
    plot.xaxis.formatter = DatetimeTickFormatter(seconds=["%M:%S"],
                                            minutes=["%R"],
                                            minsec=["%M:%S"],
                                            hours=["%R"],
                                            hourmin = ["%m/%d %R"],
                                            days = ['%m/%d'])
    plot.toolbar.logo = None
    legend = Legend()
    # legend.items = [LegendItem(label="--- Left Axis ---"   , renderers=[])]
    legend.items = []

    #########   Setup Y axes
    ## Colors
    plot.yaxis.visible = False
    extra_y_ranges = {}

    for i in range(len(graphDict['Yaxes'])):
        ya = graphDict['Yaxes'][i]
        eyrName = 'Y%s_axis' % i
        clr = ya['color_map']
        if clr is None: clr = graphDict["graph_color_map"]
        ya["cmap"] = myPalette.Palette(clr, graphDict['max_palette_len'], loggingLevel=helperFunctionLoggingLevel)
        clr = ya['color']
        if clr is None: clr = "black"
        side = ya['location']
        extra_y_ranges[eyrName] = DataRange1d(range_padding = 0.01)
        plot.extra_y_ranges = extra_y_ranges
        plot.add_layout(LinearAxis(
                y_range_name=eyrName,
                axis_label=ya['title'],
                axis_line_color=clr,
                major_label_text_color=clr,
                axis_label_text_color=clr,
                major_tick_line_color=clr,
                minor_tick_line_color=clr
            ), side)


    for i in range(len(graphDict['items'])):
        item = graphDict['items'][i]
        logger.info('--------------  %s  ------------' % item['dataname'])
        ya = graphDict['Yaxes'][item['axisNum']]
        colorGroup = ya['title']
        query = item['query'].format(
              my_schema=hostItem['myschema']
            , ha_schema=hostItem['haschema']
            , BeginDate='{BeginDate}'       # Leave {BeginDate} unmolested; it is for later replacement.
            )
        if item['dataTimeZone'] == 'UTC':
            dataTimeOffsetUTC = 0
        else:
            dataTimeOffsetUTC = hostItem['ServerTimeFromUTC']
        data = GetData(item['datafile'], query, dataTimeOffsetUTC, hostItem)
        if data is None:
            logger.warning('item "%s" of graph "%s" has no data and is skipped.' % (item['dataname'], graphDict['GraphTitle']))
            continue
        else:
            logger.debug('Got %s rows of data.' % data.size)
        data = ColumnDataSource(data)
        logger.debug('data column names are: %s; num rows is:  %s' % (data.column_names, data.to_df().size))
        yRangeName = 'Y%s_axis' % item['axisNum']
        for thisCol in data.column_names[1:]:
            logger.debug('Column "%s" is plotted against y axis: "%s"' % (thisCol, yRangeName))
            itemColor = item["color"]
            if item["color"] is None:
                itemColor = ya['cmap'].nextColor(colorGroup)
            else:
                logger.debug('item color "%s" is defined in the item definition.' % itemColor)
            r = eval('''plot.%s(x=data.column_names[0]
                , y = thisCol
                , source=data
                , color = itemColor, alpha=0.5
                , muted_color = itemColor, muted_alpha=1
                , name = thisCol
                , y_range_name=yRangeName)'''%item['lineType'])
            for (k, v) in item['lineMods'].items():
                s = 'r.%s = %s'%(k, v)
                logger.debug('Executing line mod "%s"' % s)
                exec(s)
            extra_y_ranges[yRangeName].renderers.append(r)
            if item['includeInLegend']: legend.items.append(LegendItem(label=thisCol, renderers=[r]))
    plot.add_layout(legend)
    plot.legend.location = "top_left"
    plot.legend.click_policy = "mute"
    plot.add_tools(HoverTool(
        tooltips=[
              ( '',  '$name' ) # use @{ } for field names with spaces
            , ( '',  '$y{0.0}' ) # use @{ } for field names with spaces
            , ( '',   '@Time{%F %T}'   )
            ],
            formatters={
                'Time' : 'datetime' # use 'datetime' formatter for 'x' field
                                        # use default 'numeral' formatter for other fields
            }))

    # show(plot)
    html = file_html(plot, res, graphDict['GraphTitle'])
    f = open(graphDict["outputFile"], mode='w')
    f.write(html)
    f.close()
    view(graphDict["outputFile"], new='tab')

def GetConfigFilePath():
    fp = os.path.join(ProgPath, 'secrets.ini')
    if not os.path.isfile(fp):
        fp = os.environ['PrivateConfig']
        if not os.path.isfile(fp):
            logger.error('No configuration file found: %s', fp)
            sys.exit(1)
    logger.info('Using configuration file at: %s', fp)
    return fp

def main():
    global DelOldCsv, SaveCSVData, DBHostDict, LocalDataOnly, DatabaseReadDelta, helperFunctionLoggingLevel, PP

    # print(f"In main, logger is {logger.__dict__!r}, and its parent is {logger.parent.__dict__!r}")

    RCGraphs = {'RCSolar', 'RCLaundry', 'RCHums', 'RCTemps', 'RCWater', 'RCPower', 'RCHeaters'}
    SSGraphs = {'SSFurnace', 'SSTemps', 'SSHums', 'SSMotion', 'SSLights'}
    kwargs = {'loggingLevel': helperFunctionLoggingLevel}
    cfg = MakeParams( **kwargs)
    setConsoleLoggingLevel(helperFunctionLoggingLevel)      # in case function changed it.
    if cfg is None:
        critical(f"Could not create parameters.  Must quit.")
        return
    else:
        args = Prodict.from_dict(cfg)
        debug(f"MakeParams returns non None dictionary, so args (and PP) become: {args}")
        PP = Prodict.from_dict(cfg)

    debug(f"We have program configuration parameters: {cfg}")
    debug(f"We have program keyword parameters: {kwargs}")
    Verbosity = cfg['Verbosity']        # Note that this is NOT a logging level.

    DelOldCsv = args.DeleteOldCSVData
    SaveCSVData = not args.DontSaveCSVData
    LocalDataOnly = args.LocalDataOnly
    numDays = float(args.NumDays)
    DatabaseReadDelta = float(args.DatabaseReadDelta)

    desired_plots = set()
    logger.debug('There are %s plot items specified on the command line.' % len(args.plots))
    # # "flatten" and add args.plot items to desired_plots
    # from itertools import chain
    # flatten = chain.from_iterable

    # debug(f"args.plots is {args.plots}")
    # desired_plots = set(flatten([args.plots,]))
    for i in range(len(args.plots)):
        itm = args.plots[i]
        logger.debug('Plots item %s is %s' % (i, itm))
        if len(itm) > 0:
            if isinstance(itm, str):
                logger.debug('plots item is a str: "%s"' % itm)
                desired_plots.add(itm)
            elif isinstance(itm, list):
                logger.debug('plots item is a list')
                for j in itm:
                    desired_plots.add(j)

    logger.debug('Desired plots is: %s'%(desired_plots,))

#    allKnownPlots = SSGraphs.union(RCGraphs)
    logger.info('Using graph definitions from "%s"'%args.GraphDefsFileName)
    GraphDefs, _ = GetGraphDefs(args.GraphDefsFileName, loggingLevel=helperFunctionLoggingLevel)

    #  Here we compute some helper fields in the GraphDefs dictionary.
    #  Do this here because we don't want to pollute the GetGraphDefs function
    # with a bunch of imports and code it doesn't need to do its job.
    DBHosts = set()
    gdks = set(GraphDefs.keys())
    logger.debug('Graphs defined in the graph defs file are: %s' % gdks)
    if len(desired_plots) > 0:
        plotlist = list(desired_plots)
        for plt in plotlist:
            if plt not in gdks:
                logger.warning('Plot: "%s" is unknown, and will be ignored.' % plt)
                desired_plots.remove(plt)
    if len(desired_plots) == 0:     # no options given, and no config graphs, provide a default set.
        desired_plots = gdks        # all graphs
        logger.debug('No known plots specified on command line; plot all known.')
    logger.info('Desired plots set is: %s', desired_plots)
    logger.info('Command line contains RC graphs: %s', not RCGraphs.isdisjoint(desired_plots))
    logger.info('Command line contains SS graphs: %s', not SSGraphs.isdisjoint(desired_plots))

    desired_plots = desired_plots.intersection(gdks)
    if len(desired_plots) == 0:
        logger.debug('No desired plots are defined in the graph defs file.')
        exit(4)
    logger.debug('Desired plots set after checking the graph defs file is: %s', desired_plots)
    for k in gdks:
        logger.debug('Checking if desired plot "%s" is defined.' % k)
        if k not in desired_plots:
            del GraphDefs[k]    # delete graph defs for undesired plots
            continue
        gd = GraphDefs[k]
        DBHosts.add(gd["DBHost"])
        numYAxes = len(gd['Yaxes'])
        for a in gd['Yaxes']:
            a['vars'] = []
        for itm in gd['items']:
            if int(itm['axisNum']) >= numYAxes:
                logger.error('In GraphDefs["%s"], item "%s" references an unknown Y axis.' % (k, itm["dataname"]))
                exit(2)
            gd['Yaxes'][itm['axisNum']]['vars'].extend(itm['variableNames'])
        mpl = 0
        for a in gd['Yaxes']:
            mpl = max(mpl, len(a['vars']))
        gd['max_palette_len'] = mpl
        pass
    if len(GraphDefs) == 0:
        logger.warning('None of the desired plots are in the graph definitions file.')
        exit(3)
    gdks = sorted(GraphDefs.keys())
    logger.debug('Sorted list of graphs (from GraphDefs.keys): %s' % gdks)

    # logger.debug('GraphDefs dict is: %s' % json.dumps(GraphDefs, indent=2))
    if LocalDataOnly:
        ServerTimeFromUTC = dt.utcnow() - dt.now()      # Use current system as database host for time purposes.
        for h in DBHosts:       # create "dummy" host entry
            logger.debug('Creating "dummy" host entry for %s' % h)
            DBHostDict[h] = dict()
            dbhd = DBHostDict[h]
            dbhd['DBEngine'] = None
            dbhd['haschema'] = 'haschema'
            dbhd['myschema'] = 'myschema'
            dbhd['conn'] = None
            dbhd['twoWeeksAgo'] = (dt.utcnow() + ServerTimeFromUTC - timedelta(days=14))
            dbhd['BeginTime'] = (dt.utcnow() + ServerTimeFromUTC - timedelta(days=numDays))
            dbhd['ServerTimeFromUTC'] = ServerTimeFromUTC
            logger.debug("%s Server time offset from UTC: %s" % (h, dbhd['ServerTimeFromUTC']))
            logger.debug("%s BeginTime: %s" % (h, dbhd['BeginTime']))
            logger.debug("%s twoWeeksAgo: %s" % (h, dbhd['twoWeeksAgo']))
        # Datetime objects are not JSON serializable; don't dump host dict.
        # logger.debug('Dummy DBHostDict is: %s' % json.dumps(DBHostDict, indent=2))
        for k in gdks:
            logger.info('             ##############   Preparing graph "%s"   #################' % k)
            ShowGraph(GraphDefs[k])
        return

    for h in DBHosts:
        DBHostDict[h] = dict()
        dbhd = DBHostDict[h]
        user = cfg[f'{h}_database_reader_user']
        pwd  = cfg[f'{h}_database_reader_password']
        host = cfg[f'{h}_database_host']
        port = cfg[f'{h}_database_port']
        dbhd['haschema'] = cfg[f'{h}_ha_schema']
        dbhd['myschema'] = cfg[f'{h}_my_schema']
        logger.info(f"{h} user {user}")
        logger.info(f"{h} pwd {pwd}")
        logger.info(f"{h} host {host}")
        logger.info(f"{h} port {port}")
        logger.info(f"{h} haschema {dbhd['haschema']}")
        logger.info(f"{h} myschema {dbhd['myschema']}")

        # schema in connection string is not important since all queries specify the
        #   schema for the table being accessed.
        connstr = 'mysql+pymysql://{user}:{pwd}@{host}:{port}/{schema}'.format(user=user, pwd=pwd, host=host, port=port, schema=dbhd['haschema'])
        logger.debug("%s database connection string: %s" % (h, connstr))
        Eng = create_engine(connstr, echo = True if Verbosity>=2 else False, logging_name = logger.name)
        dbhd['DBEngine'] = Eng
        logger.debug(Eng)
        with Eng.connect() as conn, conn.begin():
            dbhd['conn'] = conn
            result = conn.execute("select timestampdiff(hour, utc_timestamp(), now());")
            for row in result:
                ServerTimeFromUTC = timedelta(hours=row[0])
            dbhd['twoWeeksAgo'] = (dt.utcnow() + ServerTimeFromUTC - timedelta(days=14))
            dbhd['BeginTime'] = (dt.utcnow() + ServerTimeFromUTC - timedelta(days=numDays))
            dbhd['ServerTimeFromUTC'] = ServerTimeFromUTC
            logger.debug("%s Server time offset from UTC: %s" % (h, dbhd['ServerTimeFromUTC']))
            logger.debug("%s BeginTime: %s" % (h, dbhd['BeginTime']))
            logger.debug("%s twoWeeksAgo: %s" % (h, dbhd['twoWeeksAgo']))
            for k in gdks:
                gd = GraphDefs[k]
                if gd["DBHost"] == h:
                    logger.info(f'             ##############   Preparing graph "{k}"   #################')
                    ShowGraph(GraphDefs[k])
        # "DBEngine" and "conn" items in DBHostDict are not serializable, so can't dump them
    # logger.debug('DBHostDict is: %s' % json.dumps(DBHostDict, indent=2))

if __name__ == "__main__":

    setConsoleLoggingLevel(logging.INFO)

    logger.info(f'####################  {ProgName} starts  @  {dt.now().isoformat(sep=" ")}   #####################')
    setConsoleLoggingLevel(helperFunctionLoggingLevel)
    main()
    setConsoleLoggingLevel(logging.INFO)
    logger.info(f'####################  {ProgName} all done  @  {dt.now().isoformat(sep=" ")}   #####################')
    logging.shutdown()
    pass
