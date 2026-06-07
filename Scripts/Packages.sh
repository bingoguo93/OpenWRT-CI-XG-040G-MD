#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# 安装和更新软件包
UPDATE_PACKAGE() {
  local PKG_NAME="$1"
  local PKG_REPO="$2"
  local PKG_BRANCH="$3"
  local PKG_SPECIAL="$4"
  local PKG_LIST=("$PKG_NAME" $5)
  local REPO_NAME="${PKG_REPO#*/}"

  echo " "
  echo "=============================="
  echo "Update package: $PKG_NAME"
  echo "Repository: https://github.com/$PKG_REPO"
  echo "Branch: $PKG_BRANCH"
  echo "Special: $PKG_SPECIAL"
  echo "=============================="

  # 删除 feeds 中可能存在的同名软件包
  for NAME in "${PKG_LIST[@]}"; do
    echo "Search directory: $NAME"

    if [ ${#NAME} -le 3 ]; then
      FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 4 -type d -iname "$NAME" 2>/dev/null)
    else
      FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 4 -type d \( -iname "$NAME" -o -iname "*$NAME*" \) 2>/dev/null)
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

  # 删除 package 目录下可能残留的同名目录
  for NAME in "${PKG_LIST[@]}"; do
    if [ -d "./$NAME" ]; then
      rm -rf "./$NAME"
      echo "Delete local package directory: ./$NAME"
    fi
  done

  # 删除可能残留的仓库目录
  if [ -d "./$REPO_NAME" ]; then
    rm -rf "./$REPO_NAME"
    echo "Delete old repo directory: ./$REPO_NAME"
  fi

  # 克隆 GitHub 仓库
  git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git"

  # 处理克隆的仓库
  if [[ "$PKG_SPECIAL" == "pkg" ]]; then
    find ./"$REPO_NAME"/*/ -maxdepth 4 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
    rm -rf ./"$REPO_NAME"/
  elif [[ "$PKG_SPECIAL" == "name" ]]; then
    if [ "$REPO_NAME" != "$PKG_NAME" ]; then
      mv -f "$REPO_NAME" "$PKG_NAME"
    else
      echo "$REPO_NAME already has target name, skip rename."
    fi
  else
    echo "Keep repository directory: ./$REPO_NAME"
  fi
}

# ============================================================
# 主题：aurora
# WRT_THEME=aurora 时，Settings.sh 会写入：
# CONFIG_PACKAGE_luci-theme-aurora=y
# CONFIG_PACKAGE_luci-app-aurora-config=y
# ============================================================
UPDATE_PACKAGE "luci-theme-aurora" "eamonxg/luci-theme-aurora" "master" "name" "aurora"
UPDATE_PACKAGE "luci-app-aurora-config" "eamonxg/luci-app-aurora-config" "master" "name" "aurora-config"

# ============================================================
# PassWall
# ============================================================
UPDATE_PACKAGE "passwall-packages" "Openwrt-Passwall/openwrt-passwall-packages" "main" "" "xray-core chinadns-ng dns2socks ipt2socks tcping microsocks"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg" "luci-app-passwall"

# ============================================================
# Lucky
# ============================================================
UPDATE_PACKAGE "lucky" "gdy666/luci-app-lucky" "main" "name" "luci-app-lucky luci-i18n-lucky"

# ============================================================
# gecoosac / microsocks LuCI
# VIKINGYFY/packages 内通常包含 luci-app-gecoosac、luci-app-microsocks 等扩展包
# ============================================================
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "gecoosac luci-app-gecoosac luci-app-microsocks"

# ============================================================
# Airoha NPU 插件，原仓库已有，建议保留
# ============================================================
UPDATE_PACKAGE "luci-app-airoha-npu" "bingoguo93/luci-app-airoha-npu" "main"

# ============================================================
# 更新软件包版本函数
# 当前没有主动调用，保留备用
# ============================================================
UPDATE_VERSION() {
  local PKG_NAME="$1"
  local PKG_MARK="${2:-false}"
  local PKG_FILES
  PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 4 -type f -wholename "*/$PKG_NAME/Makefile")

  if [ -z "$PKG_FILES" ]; then
    echo "$PKG_NAME not found!"
    return
  fi

  echo -e "\n$PKG_NAME version update has started!"

  for PKG_FILE in $PKG_FILES; do
    local PKG_REPO
    local PKG_TAG
    local OLD_VER
    local OLD_URL
    local OLD_FILE
    local OLD_HASH
    local PKG_URL
    local NEW_VER
    local NEW_URL
    local NEW_HASH

    PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" "$PKG_FILE")
    PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

    OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
    OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
    OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
    OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

    PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")
    NEW_VER=$(echo "$PKG_TAG" | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
    NEW_URL=$(echo "$PKG_URL" | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
    NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

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

# 引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
  source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
