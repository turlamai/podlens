#!/bin/sh
# raco distribute keeps its relative bin/ + lib/ layout; the packaged entry
# resolves public/ next to the executable (../public from bin/).
exec /app/podlens/bin/podlens "$@"