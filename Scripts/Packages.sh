PATCH_DAED_USER_AGENT() {
  local DAED_MAKEFILE="./dae/daed/Makefile"

  if [ ! -f "$DAED_MAKEFILE" ]; then
    echo "Daed Makefile not found, skip User-Agent patch."
    return 1
  fi

  python3 <<'PY'
from pathlib import Path

p = Path("./dae/daed/Makefile")
s = p.read_text()

ua = "v2rayN/7.22.5"

marker = r'''git -C $(PKG_BUILD_DIR)/dae-core checkout $(CORE_HASH_SHORT) ; \'''

inject = r'''git -C $(PKG_BUILD_DIR)/dae-core checkout $(CORE_HASH_SHORT) ; \
	find $(PKG_BUILD_DIR)/dae-core -type f -name "*.go" -exec sed -i -E 's#req\.Header\.Set\("User-Agent",[[:space:]]*fmt\.Sprintf\("dae/%v \(like v2rayA/1\.0 WebRequestHelper\) \(like v2rayN/1\.0 WebRequestHelper\)",[[:space:]]*config\.Version\)\)#req.Header.Set("User-Agent", "v2rayN/7.22.5")#g; s#v2rayN/1\.0 WebRequestHelper#v2rayN/7.22.5#g; s#v2rayA/1\.0 WebRequestHelper#v2rayN/7.22.5#g' {} \; ; \
	if grep -R "v2rayN/1.0\|v2rayA/1.0" $(PKG_BUILD_DIR)/dae-core ; then echo "DAE User-Agent patch failed: old UA still exists"; exit 1; fi ; \
	grep -R "v2rayN/7.22.5" $(PKG_BUILD_DIR)/dae-core || { echo "DAE User-Agent patch failed: new UA not found"; exit 1; } ; \'''

if "DAE User-Agent patch failed: old UA still exists" in s:
    print("Daed User-Agent patch already exists.")
else:
    if marker not in s:
        print("Daed checkout marker not found, User-Agent patch was not inserted.")
        raise SystemExit(1)

    s = s.replace(marker, inject, 1)
    p.write_text(s)
    print(f"Daed subscription User-Agent patched to {ua}.")
PY
}
