_prefix = (...):match("(.+%.)[^%.]+$") or ""
return require(_prefix .. "naw")
