'''
Define the schema for graph definition dictionary.
'''

import os               #   https://docs.python.org/3/library/os.html
import sys              #   https://docs.python.org/3/library/sys.html
import json             #   https://docs.python.org/3/library/json.html
import toml             #   https://github.com/uiri/toml    https://github.com/toml-lang/toml
# comment json strips python and "//" comments form json before applying json.load routines.
import commentjson      #   https://github.com/vaidik/commentjson       https://commentjson.readthedocs.io/en/latest/
# Lark is used by commentjson -- import commented out, but here for documentation.
# import lark             #   https://github.com/lark-parser/lark    https://lark-parser.readthedocs.io/en/latest/
import logging          #   https://docs.python.org/3/library/logging.html
from progparams.GetLoggingDict import setConsoleLoggingLevel, setLogFileLoggingLevel, getConsoleLoggingLevel, getLogFileLoggingLevel

#   https://github.com/keleshev/schema
from schema import Schema, And, Or, Use, Optional, SchemaError
# import matplotlib.cm as cm
import bokeh.palettes as bp
import bokeh.colors as bc

import glob
from itertools import chain
flatten = chain.from_iterable

logger = logging.getLogger(__name__)
debug = logger.debug
critical = logger.critical
info = logger.info

MyPath = os.path.dirname(os.path.realpath(__file__))
ProgName, ext = os.path.splitext(os.path.basename(sys.argv[0]))
ProgPath = os.path.dirname(os.path.realpath(sys.argv[0]))

# logger.debug('bokeh __palettes__ are: %s' % bp.__palettes__)
bokehKnownColors = bc.named.__all__
#  This makes the VSCode happy, but I don't think it will work as I intend.
# bokehPaletteFamilies = list(bp._PalettesModule.all_palettes)
##  The following works for Python, but not for VSCode.
bokehPaletteFamilies = list(bp.all_palettes.keys())
palettesAndColors = bokehPaletteFamilies + bokehKnownColors

# logger.debug('bokeh palette families are: %s' % bokehPaletteFamilies)

            # And(str, lambda s: s in cm.datad.keys())
#                         # And(str, lambda s: s in cm.datad.keys())
# Or(
gds = {str: {'GraphTitle': str
        , 'DBHost': And(Use(str.lower), Use(str.lower), lambda s: s in ('rc', 'ss'), error='DBHost must be "RC" or "SS"')
        , 'outputFile': str
        , Optional('ShowGraph', default=True): bool
        , Optional('graph_color_map', default='Dark2'): Or(
            And(str, lambda s: s in bokehPaletteFamilies)
            , None, error='Graph color map not defined.')
        , 'XaxisTitle': str
        , 'Yaxes': [{'title': str
                    , Optional('color_map', default=None): Or(
                        And(str, lambda s: s in palettesAndColors)
                        , None, error='Axis color map not defined.')
                    , Optional('color', default=None): Or(
                        And(str, lambda s: s in bokehKnownColors)
                        , None, error='Axis color not defined.')
                    , Optional('location', default='left'):
                        And(str, lambda s: s in ('left', 'right'), error='Axis location must be "left" or "right".')}]
        , 'items': [ { 'query': Or(str, None)
                , 'variableNames': [str]
                , 'datafile': str
                , 'dataname': str
                , Optional('axisNum', default=0): Use(int)
                , Optional('includeInLegend', default=True): Use(bool)
                , Optional('lineType', default='line'):
                        And(str, lambda s: s in ('line', 'step'), error='Item lineType must be "line" or "step".')
                , Optional('dataTimeZone', default='serverLocal'):
                        And(str, lambda s: s in ('serverLocal', 'UTC'), error='Item dataTimeZone must be "serverLocal" or "UTC".')
                , Optional('lineMods', default={"glyph.line_width": "2", "muted_glyph.line_width": "4"}): {str: str}
                , Optional('color_map', default=None): Or(
                    And(str, lambda s: s in bokehPaletteFamilies)
                    , None, error='Axis color map not defined.')
                , Optional('color', default=None): Or(
                    And(str, lambda s: s in bokehKnownColors)
                    , None, error='Axis color not defined.') } ] } }

# Doesn't work since some of the keys are class objects defined in schema.
# Can't pickle gds either.
# with open(os.path.join(MyPath, "GraphDefsSchema.json"), 'w') as file:
#     json.dump(gds, file, indent=2)

def GetGraphDefs(GraphDefFile=None, *args, **kwargs):
    '''
    Load a toml or json file with graph definitions in it.
    The graph definitions dictionary is validated.
    '''
    logger.debug(f"Entered GetGraphDefs with argument {GraphDefFile}, and kwargs {kwargs!r}")
    logger.debug('MyPath in GraphDefinitions.GetGraphDefs is: %s' % MyPath)

    if kwargs.get('loggingLevel') is not None:
        setConsoleLoggingLevel(kwargs.get('loggingLevel'))
        pass

    if kwargs.get('GraphDefFile') is not None:
        fns = kwargs['GraphDefFile']
        if isinstance(fns, str): fns = (fns,)
    else:
        if GraphDefFile is None: GraphDefFile = "OneLineGraph"
        # Look for .toml, .jsonc and .json files with GraphDefFile in the main program's dir then in cwd.
        fns = [   os.path.join(ProgPath, f"{GraphDefFile}*.toml")
                , os.path.join(ProgPath, f"{GraphDefFile}*.jsonc")
                , os.path.join(ProgPath, f"{GraphDefFile}*.json")
                , f"{GraphDefFile}*.toml"
                , f"{GraphDefFile}*.jsonc"
                , f"{GraphDefFile}*.json"
              ]
        debug(f"Looking for graph definition file in default locations.")
    # glob process graph def paths
    # Make a list of actual files to read.
    fns = list(flatten([glob.glob(x) for x in fns]))

    debug(f"Looking for first good JSON or TOML graph defs file in {fns!r}")
    if fns is None: return None, None     # no graph defs, and no files to read it from.
    for fn in fns:
        try:
            debug(f"Trying to load graph definitions from file: {fn}")
            fnExt = os.path.splitext(fn)[1]
            if fnExt == ".json" or fnExt == ".jsonc":
                GraphDefs = commentjson.load(open(fn))
            elif fnExt == ".toml":
                GraphDefs = toml.load(fn)
            else:
                critical(f"Unrecognized file type from which to load graph definitions: {fnExt}")
                return None, fn
            debug(f"Successfully loaded GraphDefs: {GraphDefs}\n\nFrom file {fn}")
            break       #  exit the for loop without doing the else clause.
        except json.JSONDecodeError as e:
            info(f"Json file: {fn} did not load successfully: {e}")
        except FileNotFoundError as f:
            info(f"Param file: {fn} does not exist. {f}")
        except IsADirectoryError as d:
            info(f"Param file: {fn} is a directory! {d}")
        except toml.TomlDecodeError as t:
            info(f"Toml file: {fn} did not load successfully: {t}")
    else:
        critical(f'No graph definitions file was found and loaded.')
        return None, None
    try:
        debug(f'Validating the loaded graph definitions dictionary.')
        GraphDefsSchema = Schema(gds, name = 'Graphing Schema')
        GraphDefs = GraphDefsSchema.validate(GraphDefs)
        logger.debug('Graph definitions file is valid.')
    except SchemaError as e:
        logger.critical('Graph definition dictionary is not valid.  %s', e)
        logger.debug('%s' % e.autos)
        return None, fn
    return GraphDefs, fn
