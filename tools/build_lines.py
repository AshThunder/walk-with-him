#!/usr/bin/env python3
"""Builds data/lines.json. KJV lines come verbatim from data/kjv.json (kind=kjv). Invented lines are tiny and marked kind=fiction."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
K = json.load(open(ROOT + "/data/kjv.json"))
def full(k): return K[k]["text"]
def part(k, s):
    assert s in K[k]["text"], (k, s); return s
L = {}
def kjv(i, speaker, key, text=None): L[i] = {"speaker": speaker, "kind": "kjv", "ref": K[key]["ref"], "text": text or full(key)}
def fic(i, speaker, text): L[i] = {"speaker": speaker, "kind": "fiction", "ref": "", "text": text}
for k in ["lk4_16", "j2_1", "j2_2", "j2_6", "j2_9", "j2_11", "ps119_105", "prov3_5", "ps34_8"]: kjv("n_" + k, "narrator", k)
kjv("j_woman", "jesus", "j2_4", part("j2_4", "Woman, what have I to do with thee? mine hour is not yet come."))
kjv("j_fill", "jesus", "j2_7", part("j2_7", "Fill the waterpots with water."))
kjv("j_draw", "jesus", "j2_8", part("j2_8", "Draw out now, and bear unto the governor of the feast."))
kjv("m_nowine", "mary", "j2_3", part("j2_3", "They have no wine."))
kjv("m_servants", "mary", "j2_5", part("j2_5", "Whatsoever he saith unto you, do it."))
kjv("s_taste", "steward", "j2_10", full("j2_10"))
fic("j_invite", "jesus", "Come with me to Cana. There is a wedding, and we are invited.")
fic("naomi_ask", "naomi", "Child, I dropped my father's scroll near the olive tree. Could you find it for me?")
fic("naomi_thanks", "naomi", "Bless you! Keep its words close, child. They will light your road.")
fic("sv_brim", "servant", "They are full, right up to the brim.")
fic("g1", "guest", "Wine? But those jars held only water!")
fic("g2", "guestf", "Taste it! I have never tasted wine so good.")
fic("g3", "guest", "Blessed be God!")
json.dump(L, open(ROOT + "/data/lines.json", "w"), indent=1, ensure_ascii=False)
print(len(L), "lines")
