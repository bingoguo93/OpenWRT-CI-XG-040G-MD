#!/bin/bash

# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
# 安装和更新软件包

UPDATE_PACKAGE() {
  local PKG_NAME=$1
  local PKG_REPO=$2
  local PKG_BRANCH=$3
  local PKG_SPECIAL=$4
  local PKG_LIST=("$PKG_NAME" $5)
  local REPO_NAME=${PKG_REPO#*/}

  echo " "

  # 删除本地可能存在的同名软件包
  # 修复点：
  # 1. dae / vnt 这类短包名不使用 *dae* 模糊匹配，避免误删 libdaemon
  # 2. LuCI 主题/插件保持标准目录名，例如 luci-theme-aurora、luci-app-aurora-config
  for NAME in "${PKG_LIST[@]}"; do
    echo "Search directory: $NAME"

    if [ ${#NAME} -le 3 ]; then
      FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$NAME" 2>/dev/null)
    else
      FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d \( -iname "$NAME" -o -iname "*$NAME*" \) 2>/dev/null)
    fi

    if [ -n "$FOUND_DIRS" ]; then
      while read -r DIR; do
        rm -rf "$DIR"
        echo "Delete directory: $DIR"
      done <<< "$FOUND_DIRS"
    else
      echo "Not found directory: $NAME"
    fi
  done

  # 克隆 GitHub 仓库
  git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git"

  # 处理克隆的仓库
  if [[ "$PKG_SPECIAL" == "pkg" ]]; then
    find ./"$REPO_NAME"/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
    rm -rf ./"$REPO_NAME"/
  elif [[ "$PKG_SPECIAL" == "name" ]]; then
    if [ "$REPO_NAME" != "$PKG_NAME" ]; then
      mv -f "$REPO_NAME" "$PKG_NAME"
    else
      echo "$REPO_NAME already has target name, skip rename."
    fi
  fi
}

PATCH_DAED_USER_AGENT() {
  local DAED_MAKEFILE="./dae/daed/Makefile"

  if [ ! -f "$DAED_MAKEFILE" ]; then
    echo "Daed Makefile not found, skip User-Agent patch."
    return 1
  fi

  python3 <<'PY'
from pathlib import Path
import re

p = Path("./dae/daed/Makefile")
s = p.read_text()

if "DAE_USER_AGENT_PATCH_BY_CHATGPT_V2" in s:
    print("Daed User-Agent patch already exists.")
    raise SystemExit(0)

patch_block = r'''
	# DAE_USER_AGENT_PATCH_BY_CHATGPT_V2
	# 修复部分订阅服务提示 v2rayN 版本过旧：
	# 只替换 UA 字符串，不替换 req.Header.Set 整句，避免 Go import config 未使用导致编译失败。
	if [ -d "$(PKG_BUILD_DIR)/dae-core" ]; then \
		find $(PKG_BUILD_DIR)/dae-core -type f -name "*.go" -exec perl -0pi -e 's#v2rayN/1\.0#v2rayN/7.22.5#g; s#v2rayA/1\.0#v2rayN/7.22.5#g' {} \; ; \
	else \
		find $(PKG_BUILD_DIR) -type f -name "*.go" -exec perl -0pi -e 's#v2rayN/1\.0#v2rayN/7.22.5#g; s#v2rayA/1\.0#v2rayN/7.22.5#g' {} \; ; \
	fi
	if grep -R "v2rayN/1.0\|v2rayA/1.0" $(PKG_BUILD_DIR)/dae-core 2>/dev/null; then \
		echo "DAE User-Agent patch failed: old UA still exists"; \
		exit 1; \
	fi
	grep -R "v2rayN/7.22.5" $(PKG_BUILD_DIR)/dae-core 2>/dev/null || true
'''

m = re.search(r"(define Build/Prepare\n.*?)(\nendef)", s, flags=re.S)
if m:
    s = s[:m.start()] + m.group(1) + patch_block + m.group(2) + s[m.end():]
    p.write_text(s)
    print("Daed subscription User-Agent patched to v2rayN/7.22.5.")
else:
    print("Build/Prepare block not found in daed Makefile, User-Agent patch failed.")
    raise SystemExit(1)
PY
}

# 调用示例
# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"

# 主题包：必须保持标准 LuCI 包目录名，否则 luci-light 会找不到 luci-theme-xxx
UPDATE_PACKAGE "luci-theme-argon" "sbwml/luci-theme-argon" "openwrt-25.12" "name" "argon"
UPDATE_PACKAGE "luci-theme-shadcn" "eamonxg/luci-theme-shadcn" "main" "name" "shadcn"

# Aurora 主题：WRT_THEME=aurora 时 Settings.sh 会选择 CONFIG_PACKAGE_luci-theme-aurora=y
UPDATE_PACKAGE "luci-theme-aurora" "eamonxg/luci-theme-aurora" "master" "name" "aurora"

# Aurora 配置插件：Settings.sh 会选择 CONFIG_PACKAGE_luci-app-aurora-config=y
UPDATE_PACKAGE "luci-app-aurora-config" "eamonxg/luci-app-aurora-config" "master" "name" "aurora-config"

UPDATE_PACKAGE "luci-theme-kucat" "sirpdboy/luci-theme-kucat" "master" "name" "kucat"
UPDATE_PACKAGE "luci-app-kucat-config" "sirpdboy/luci-app-kucat-config" "master" "name" "kucat-config"

# 已移除 homeproxy
# UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"

UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "sbwml/luci-app-diskman" "main"
UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"

# 已移除 mosdns
# UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"

# Lucky：仓库克隆到 package/lucky，内含 lucky 与 luci-app-lucky
UPDATE_PACKAGE "lucky" "gdy666/luci-app-lucky" "main" "name" "luci-app-lucky luci-i18n-lucky"

# Daed：仓库克隆到 package/dae，内含 daed 与 luci-app-daed
UPDATE_PACKAGE "dae" "QiuSimons/luci-app-daed" "kix" "name" "daed luci-app-daed"
PATCH_DAED_USER_AGENT

UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"
UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "gecoosac luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"
UPDATE_PACKAGE "luci-app-airoha-npu" "bingoguo93/luci-app-airoha-npu" "main"

UPDATE_VERSION() {
  local PKG_NAME=$1
  local PKG_MARK=${2:-false}
  local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

  if [ -z "$PKG_FILES" ]; then
    echo "$PKG_NAME not found!"
    return
  fi

  echo -e "\n$PKG_NAME version update has started!"

  for PKG_FILE in $PKG_FILES; do
    local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" "$PKG_FILE")
    local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")
    local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
    local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
    local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
    local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")
    local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")
    local NEW_VER=$(echo "$PKG_TAG" | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
    local NEW_URL=$(echo "$PKG_URL" | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
    local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

    echo "old version: $OLD_VER $OLD_HASH"
    echo "new version: $NEW_VER $NEW_HASH"

    if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
      sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
      sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
      echo "$PKG_FILE version has been updated!"
    else
      echo "$PKG_FILE version is already the latest!"
    fi
  done
}

# 已去掉 homeproxy，所以不要再主动更新 sing-box，避免它被额外拉起
# UPDATE_VERSION "sing-box"

# 引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
  source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
