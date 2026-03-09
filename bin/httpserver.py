#!/usr/bin/env python3
#
# Start local HTTP server, serving files from CWD.
# Will try case-insensitive matches if exact matches are not found.
# https://f95zone.to/threads/small-python-script-to-run-local-case-insensitive-web-server.189695/

from http.server import HTTPServer, SimpleHTTPRequestHandler, test
import os.path
import os

class NoMatch(Exception):
    pass


def find_match(folder: str, part: str):
    if os.path.exists(os.path.join(folder, part)):
        return part

    needle = part.lower()
    print(f"Looking for {needle} in {folder}")
    candidates = [f for f in os.listdir(folder) if f.lower() == needle]

    if len(candidates) > 1:
        print(f"{folder}/{part}: multiple candidates {candidates}")
        raise NoMatch()
    elif len(candidates) == 0:
        print(f"{folder}/{part}: no candidates {candidates}")
        raise NoMatch()
    else:
        print(f"{folder}/{part}: Found {candidates[0]}")
        return candidates[0]


class CaseInsensitiveRequestHandler(SimpleHTTPRequestHandler):

    def translate_path(self, path):
        safe = super().translate_path(path)
        if os.path.exists(safe):
            return safe

        print(f"Cannot find {safe}")

        rel = os.path.relpath(safe, self.directory)
        parts = rel.split(os.path.sep)

        print(f"Looking for {rel}, as parts {parts}")


        builder = self.directory
        try:
            for part in parts:
                match = find_match(builder, part)
                builder = os.path.join(builder, match)
            print(f"Build result: {builder}")
            return builder
        except NoMatch:
            return safe

PORT = 8080

if __name__ == "__main__":
    with HTTPServer(("", PORT), CaseInsensitiveRequestHandler) as httpd:
        print(f"Serving at http://localhost:{PORT}/")
        httpd.serve_forever()
