from pygments.style import Style
from pygments.token import (
    Keyword, Name, Comment, String, Error,
    Number, Operator, Generic, Literal,
)

# http://pygments.org/docs/styles/
class TubnilStyle(Style):
    default_style = ""
    styles = {
        # https://bitbucket.org/birkenfeld/pygments-main/src/default/pygments/token.py
        Comment:                '#747166',
        Keyword:                '#CB6A27 bold',
        Literal:                '#3399CC',
        String:                 '#A9D158',
        String.Delimiter:       '#E882B2',
        String.Escape:          '#797BE6',
        Number:                 '#99CC66',
        Operator:               '#3D8F9A',
        Error:                  '#ff3334 bold',
        #
        # Name:                   '#F26FBC',  # in Python, everything is a name???
        Name.Function:          '#F26FBC bold',  # bg:#4A0A2F
        Name.Class:             '#F26FBC bold',  # bg:#4A0A2F
        Name.Entity:            '#F26FBC bold',  # bg:#4A0A2F
        # Name.Namespace:         '#F26FBC bold',  # bg:#4A0A2F  # also Python imports
        Name.Constant:          '#34A2D9',
        Name.Tag:               '#7f8ee5',
        Name.Builtin:           '#1786BD',
        Name.Variable:          '#3399CC',
        Name.Exception:         '#6E9CBE',
        #
        # These deviate a bit for better rendering on console
        Generic.Inserted:       '#9ec400', #  '#cae297 bg:#11401b',
        Generic.Deleted:        '#ff3334', #  '#fdc3ba bg:#531c16',
        Generic.Heading:        '#F26FBC bold',
        Generic.Strong:         'bold',
        Generic.Emph:           'italic',
        Generic.Error:          '#ff3334 bold',
    }
