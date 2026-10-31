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
OLD = json.load(open(ROOT + "/data/lines.json")) if os.path.exists(ROOT + "/data/lines.json") else {}
for k in ["lk4_16", "j2_1", "j2_2", "j2_6", "j2_9", "j2_11", "ps119_105", "prov3_5", "ps34_8"]: kjv("n_" + k, "narrator", k)
kjv("j_woman", "jesus", "j2_4", part("j2_4", "Woman, what have I to do with thee? mine hour is not yet come."))
kjv("j_fill", "jesus", "j2_7", part("j2_7", "Fill the waterpots with water."))
kjv("j_draw", "jesus", "j2_8", part("j2_8", "Draw out now, and bear unto the governor of the feast."))
kjv("m_nowine", "mary", "j2_3", part("j2_3", "They have no wine."))
kjv("m_servants", "mary", "j2_5", part("j2_5", "Whatsoever he saith unto you, do it."))
kjv("s_taste", "steward", "j2_10", full("j2_10"))
fic("j_invite", "jesus", "Come with me to Cana. There is a wedding, and we are invited.")
fic("naomi_ask", "naomi", "Friend, I dropped my father's scroll near the olive tree. Could you find it for me?")
fic("naomi_thanks", "naomi", "Bless you! Keep its words close, friend. They will light your road.")
fic("sv_brim", "servant", "They are full, right up to the brim.")
fic("g1", "guest", "Wine? But those jars held only water!")
fic("g2", "guestf", "Taste it! I have never tasted wine so good.")
fic("g3", "guest", "Blessed be God!")
# ---- the Nativity (chapters 1-5) and the doorpost
for k in ["lk2_8", "lk2_9", "lk2_13_14", "lk2_16", "lk2_24", "lk2_38", "lk2_40", "lk2_52", "lk3_23", "mt2_1", "mt2_9", "mt2_10_11", "mt2_12"]: kjv("n_" + k, "narrator", k)
kjv("a_tidings", "angel", "lk2_10_11", full("lk2_10_11")[len("And the angel said unto them, "):])
kjv("a_sign", "angel", "lk2_12", full("lk2_12"))
kjv("sh_go", "shepherd", "lk2_15", part("lk2_15", "Let us now go even unto Bethlehem, and see this thing which is come to pass, which the Lord hath made known unto us."))
kjv("s_depart", "simeon", "lk2_29_32", full("lk2_29_32"))
kjv("w_ask", "wise", "mt2_2", part("mt2_2", "Where is he that is born King of the Jews? for we have seen his star in the east, and are come to worship him."))
fic("sh_send", "shepherd", "Keep the lambs close to the fire, little one. The night is long, and we must watch.")
fic("sh_done", "shepherd", "Well done. They are all in the fold.")
fic("sh_town", "shepherd", "Stay close to us, little one. Look into each stable and tell us where you see it.")
fic("dove_seller", "seller", "Quick, little one! Two of my doves have flown loose. Bring them back to the cage!")
fic("wise_thank", "wise", "Thank you, little one. We will follow the road you have drawn.")
# ---- v0.4.0: Lead the Flock
kjv("n_ps23_1", "narrator", "ps23_1")
kjv("n_stone_lk2_11", "narrator", "lk2_10_11", part("lk2_10_11", "For unto you is born this day in the city of David a Saviour, which is Christ the Lord.")); L["n_stone_lk2_11"]["ref"] = "Luke 2:11 (KJV)"
fic("sh_road", "shepherd", "The lambs have scattered along the road. Gather them, little one, and bring them home to the fire.")
fic("sh_camp_all", "shepherd", "Every one of them is here. You led them well.")
fic("sh_camp_lost", "shepherd", "Some wandered in the dark. Listen. They are finding the fire.")
for i, d in L.items():
    o = OLD.get(i)
    if o and o.get("text") == d["text"] and "dur" in o: d["dur"] = o["dur"]
json.dump(L, open(ROOT + "/data/lines.json", "w"), indent=1, ensure_ascii=False)
print(len(L), "lines")
