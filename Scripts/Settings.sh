#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# 配置和修复默认设置

# 移除 luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# 修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# 修改 immortalwrt.lan 关联 IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")

# WIFI 默认设置
WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"

if [ -f "$WIFI_SH" ]; then
  sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
  sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
  sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
  sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
  sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
  sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"

# 修改默认 IP 地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE

# 修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# 基础配置
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

# 引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
  echo "Applying private configurations from PRIVATE.txt..."
  cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

# 手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
  echo -e "$WRT_PACKAGE" >> ./.config
fi

# 无 WIFI 配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
  echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

# ZRAM 默认设置：启用 zram 服务，使用 lzo，默认 256MB，优先级 100
mkdir -p ./package/base-files/files/etc/uci-defaults

cat > ./package/base-files/files/etc/uci-defaults/99-zram-defaults <<'EOF'
#!/bin/sh

uci -q set system.@system[0].zram_comp_algo='lzo'
uci -q set system.@system[0].zram_size_mb='256'
uci -q set system.@system[0].zram_priority='100'
uci -q commit system

/etc/init.d/zram enable 2>/dev/null

exit 0
EOF

chmod +x ./package/base-files/files/etc/uci-defaults/99-zram-defaults

# MosDNS 默认分流配置
# 逻辑：
# 1. 启用 MosDNS
# 2. 监听 0.0.0.0:5335
# 3. redirect=1，让 dnsmasq 转发到 MosDNS
# 4. 国内域名走 local_dns：223.5.5.5 / 119.29.29.29
# 5. 非中国域名走 remote_dns：tls://8.8.8.8 / tls://1.1.1.1
# 6. 使用内置 geosite_cn / geosite_geolocation-!cn / geoip_cn 分流逻辑
cat > ./package/base-files/files/etc/uci-defaults/99-mosdns-defaults <<'EOF'
#!/bin/sh

if [ -f /etc/config/mosdns ]; then
  uci -q set mosdns.config.enabled='1'
  uci -q set mosdns.config.listen_address='0.0.0.0'
  uci -q set mosdns.config.listen_port='5335'
  uci -q set mosdns.config.configfile='/var/etc/mosdns.json'
  uci -q set mosdns.config.log_level='info'
  uci -q set mosdns.config.log_file='/var/log/mosdns.log'

  # 接管 dnsmasq
  uci -q set mosdns.config.redirect='1'
  uci -q set mosdns.config.local_dns_redirect='0'

  # 缓存
  uci -q set mosdns.config.cache='1'
  uci -q set mosdns.config.cache_size='8000'
  uci -q set mosdns.config.lazy_cache_ttl='86400'
  uci -q set mosdns.config.dump_file='0'

  # 并发与连接
  uci -q set mosdns.config.concurrent='2'
  uci -q set mosdns.config.idle_timeout='30'
  uci -q set mosdns.config.enable_pipeline='1'
  uci -q set mosdns.config.insecure_skip_verify='0'

  # 国内优先 IPv4，避免部分站点 AAAA 解析异常
  uci -q set mosdns.config.prefer_ipv4='1'
  uci -q set mosdns.config.prefer_ipv4_cn='1'
  uci -q set mosdns.config.reject_type65='1'

  # 国内 DNS：用于 geosite:cn / 白名单 / 国内回落
  uci -q set mosdns.config.custom_local_dns='1'
  uci -q delete mosdns.config.local_dns 2>/dev/null
  uci -q add_list mosdns.config.local_dns='223.5.5.5'
  uci -q add_list mosdns.config.local_dns='119.29.29.29'

  # 远程 DNS：用于 geolocation-!cn / 灰名单 / 国外域名
  uci -q delete mosdns.config.remote_dns 2>/dev/null
  uci -q add_list mosdns.config.remote_dns='tls://8.8.8.8'
  uci -q add_list mosdns.config.remote_dns='tls://1.1.1.1'

  # bootstrap DNS
  uci -q set mosdns.config.bootstrap_dns='223.5.5.5'

  # 自动更新 Geo 数据
  uci -q set mosdns.config.geo_auto_update='1'
  uci -q set mosdns.config.geo_update_day_time='4'
  uci -q set mosdns.config.geo_update_week_time='*'
  uci -q set mosdns.config.geoip_type='geoip-only-cn-private'

  # 默认不开广告过滤，避免规则下载失败影响启动
  uci -q set mosdns.config.adblock='0'

  # 默认不开流媒体单独 DNS，先使用普通国外 DNS 分流
  uci -q set mosdns.config.custom_stream_media_dns='0'

  # 不开启远程 ECS
  uci -q set mosdns.config.enable_ecs_remote='0'

  uci -q commit mosdns

  mkdir -p /etc/mosdns/rule

  touch /etc/mosdns/rule/whitelist.txt
  touch /etc/mosdns/rule/blocklist.txt
  touch /etc/mosdns/rule/greylist.txt
  touch /etc/mosdns/rule/ddnslist.txt
  touch /etc/mosdns/rule/hosts.txt
  touch /etc/mosdns/rule/redirect.txt
  touch /etc/mosdns/rule/streaming.txt
  touch /etc/mosdns/rule/local-ptr.txt
  touch /etc/mosdns/rule/cloudflare-cidr.txt

  /etc/init.d/mosdns enable 2>/dev/null
fi

exit 0
EOF

chmod +x ./package/base-files/files/etc/uci-defaults/99-mosdns-defaults

# 修复 Linux 6.18 / arm64 新增 PMU/BRBE 选项导致 CI 非交互 syncconfig 卡住
for KCFG_FILE in ./target/linux/airoha/an7581/config-*; do
  [ -f "$KCFG_FILE" ] || continue

  sed -i \
    -e '/CONFIG_ARM_CCI_PMU/d' \
    -e '/CONFIG_ARM_CCN/d' \
    -e '/CONFIG_ARM_CMN/d' \
    -e '/CONFIG_ARM_NI/d' \
    -e '/CONFIG_ARM_PMU/d' \
    -e '/CONFIG_ARM_SMMU_V3_PMU/d' \
    -e '/CONFIG_ARM_DSU_PMU/d' \
    -e '/CONFIG_ARM_SPE_PMU/d' \
    -e '/CONFIG_ARM64_BRBE/d' \
    "$KCFG_FILE"

  cat >> "$KCFG_FILE" <<'KCFGEOF'
# Fix non-interactive kernel syncconfig on Linux 6.18 arm64
# CONFIG_ARM_CCI_PMU is not set
# CONFIG_ARM_CCN is not set
# CONFIG_ARM_CMN is not set
# CONFIG_ARM_NI is not set
CONFIG_ARM_PMU=y
# CONFIG_ARM_SMMU_V3_PMU is not set
# CONFIG_ARM_DSU_PMU is not set
# CONFIG_ARM_SPE_PMU is not set
# CONFIG_ARM64_BRBE is not set
KCFGEOF

  echo "Airoha kernel config fixed: $KCFG_FILE"
done

# 修复 XG-040G-MD 启用较大插件后 kernel FIT 超过 5120k，导致 bell_xg-040g-md-uImage.itb 不生成
AIROHA_IMAGE_MK="./target/linux/airoha/image/an7581.mk"

if [ -f "$AIROHA_IMAGE_MK" ]; then
  perl -0pi -e '
    s/(define Device\/bell_xg-(?:040g|140g)-(?:md|tf).*?KERNEL_SIZE := )\d+k/${1}16384k/gs;
  ' "$AIROHA_IMAGE_MK"

  echo "Bell XG kernel size patched:"
  grep -A30 -E '^define Device/bell_xg-(040g|140g)-(md|tf)' "$AIROHA_IMAGE_MK" | grep -E 'define Device|KERNEL_SIZE'
fi

# 高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"

if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
  echo "CONFIG_FEED_nss_packages=n" >> ./.config
  echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
  echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
  echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y" >> ./.config

  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
    find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
    echo "qualcommax set up nowifi successfully!"
  fi
fi
