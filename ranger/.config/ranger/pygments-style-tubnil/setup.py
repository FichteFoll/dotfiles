from setuptools import setup

# install with:
# $ python setup.py develop --install-dir "$HOME/.local/lib/python3.7/site-packages"

setup(
    name="pygmentize-style-tubnil",
    version="0.1",
    entry_points="""
        [pygments.styles]
        tubnil = tubnil:TubnilStyle
    """,
)
