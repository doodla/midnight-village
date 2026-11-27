"""Request bodies, read so that no body can make the server fail.

DRF's JSON parser turns malformed JSON into a 400 but lets a body nested a few thousand
levels deep (``[[[[...``, a few KB) raise ``RecursionError``: a 500 and a logged
traceback on every such request, to any of the views that read a body without an
account (guest sign-up, the token views). This one answers it as malformed: 400.
``tests/core/test_open_routes.py`` sends hostile bodies to every route.
"""

from __future__ import annotations

from typing import Any

from rest_framework.exceptions import ParseError
from rest_framework.parsers import JSONParser


class SafeJSONParser(JSONParser):
    def parse(self, stream: Any, media_type: Any = None, parser_context: Any = None):
        try:
            return super().parse(stream, media_type, parser_context)
        except RecursionError as error:
            raise ParseError("JSON parse error - nested too deep") from error
