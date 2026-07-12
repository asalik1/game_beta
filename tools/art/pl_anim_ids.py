"""pl_anim_ids — print a boss character's per-direction anim_ids for a given
animation name-prefix, by calling the PixelLab MCP get_character over JSON-RPC
(keeps the huge tool output OUT of the agent context).

Usage: python pl_anim_ids.py <character_id> [name_prefix=custom-raising]
Prints lines: <suffix>=<anim_id>  for s/se/e/ne/n/nw/w/sw that are present.
"""
import os, sys, json, urllib.request

TOK = os.environ["PIXELLAB_SECRET"]
URL = "https://api.pixellab.ai/mcp"
DIRMAP = {"south": "s", "south-east": "se", "east": "e", "north-east": "ne",
          "north": "n", "north-west": "nw", "west": "w", "south-west": "sw"}


def rpc(method, params, sid=None):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    h = {"Authorization": "Bearer " + TOK, "Content-Type": "application/json",
         "Accept": "application/json, text/event-stream"}
    if sid:
        h["Mcp-Session-Id"] = sid
    req = urllib.request.Request(URL, data=body, headers=h)
    r = urllib.request.urlopen(req, timeout=60)
    sid = r.headers.get("Mcp-Session-Id", sid)
    raw = r.read().decode()
    # response may be SSE (text/event-stream): pull the data: line JSON
    payload = None
    if raw.lstrip().startswith("{"):
        payload = json.loads(raw)
    else:
        for line in raw.splitlines():
            line = line.strip()
            if line.startswith("data:"):
                payload = json.loads(line[5:].strip())
    return payload, sid


def main():
    cid = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) > 2 else "custom-raising"
    # MCP handshake: initialize -> notifications/initialized -> tools/call
    init, sid = rpc("initialize", {"protocolVersion": "2024-11-05",
                                    "capabilities": {}, "clientInfo": {"name": "pl", "version": "1"}})
    # initialized notification (no id)
    try:
        body = json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}).encode()
        h = {"Authorization": "Bearer " + TOK, "Content-Type": "application/json",
             "Accept": "application/json, text/event-stream", "Mcp-Session-Id": sid}
        urllib.request.urlopen(urllib.request.Request(URL, data=body, headers=h), timeout=30)
    except Exception:
        pass
    res, sid = rpc("tools/call", {"name": "get_character",
                                  "arguments": {"character_id": cid, "include_preview": False}}, sid)
    text = ""
    for block in res.get("result", {}).get("content", []):
        if block.get("type") == "text":
            text += block["text"]
    # parse: lines "  custom-... (south-east, 5f) ..." then a "frames: URL,URL"
    out = {}
    cur = None
    for line in text.splitlines():
        s = line.strip()
        if s.startswith(prefix) or (s.startswith("custom-") and prefix in s):
            # extract "(<dir>, Nf)"
            if "(" in s and "," in s:
                d = s[s.rfind("(") + 1:s.rfind(",")].strip()
                cur = DIRMAP.get(d)
        elif s.startswith("frames:") and cur:
            # first URL -> .../animations/<anim_id>/<dir>/0.png
            url = s.split()[1].rstrip(",")
            parts = url.split("/animations/")[1].split("/")
            out[cur] = parts[0]
            cur = None
    for suf in ["s", "se", "e", "ne", "n", "nw", "w", "sw"]:
        if suf in out:
            print("%s=%s" % (suf, out[suf]))


if __name__ == "__main__":
    main()
