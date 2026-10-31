#!/usr/bin/env python3
"""Fetch exact KJV text (public domain in the US) from bible-api.com -> data/kjv.json. Never paraphrased."""
import json, time, urllib.parse, urllib.request
REFS = {"j2_1":"John 2:1","j2_2":"John 2:2","j2_3":"John 2:3","j2_4":"John 2:4","j2_5":"John 2:5","j2_6":"John 2:6","j2_7":"John 2:7",
 "j2_8":"John 2:8","j2_9":"John 2:9","j2_10":"John 2:10","j2_11":"John 2:11","ps119_105":"Psalm 119:105","prov3_5":"Proverbs 3:5","ps34_8":"Psalm 34:8",
 "mk6_3":"Mark 6:3","lk4_16":"Luke 4:16","ps23_1":"Psalm 23:1",
 # Nativity chapters 1-5 and the age jump
 "lk2_8":"Luke 2:8","lk2_9":"Luke 2:9","lk2_10_11":"Luke 2:10-11","lk2_12":"Luke 2:12","lk2_13_14":"Luke 2:13-14","lk2_15":"Luke 2:15","lk2_16":"Luke 2:16",
 "lk2_24":"Luke 2:24","lk2_29_32":"Luke 2:29-32","lk2_38":"Luke 2:38","lk2_40":"Luke 2:40","lk2_52":"Luke 2:52","lk3_23":"Luke 3:23",
 "mt2_1":"Matthew 2:1","mt2_2":"Matthew 2:2","mt2_9":"Matthew 2:9","mt2_10_11":"Matthew 2:10-11","mt2_12":"Matthew 2:12"}
import os
out = json.load(open("data/kjv.json")) if os.path.exists("data/kjv.json") else {}   # only fetch what is missing; never rewrite verses already checked
for k, ref in REFS.items():
    if k in out: continue
    url = "https://bible-api.com/" + urllib.parse.quote(ref) + "?translation=kjv"
    for a in range(6):
        try: d = json.load(urllib.request.urlopen(url, timeout=30)); break
        except Exception: time.sleep(2 + 3 * a)
    text = " ".join(v["text"].strip().replace("\n", " ") for v in d["verses"])
    out[k] = {"ref": ref + " (KJV)", "text": " ".join(text.split())}
    time.sleep(1.1)
json.dump(out, open("data/kjv.json", "w"), indent=1, ensure_ascii=False)
for k, v in out.items(): print(k, v["ref"], "|", v["text"])
