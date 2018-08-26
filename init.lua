_prefix = (...):match("(.+%.)[^%.]+$") or ""
print(_prefix .. "naw.naw")
return require(_prefix .. "naw.naw")
