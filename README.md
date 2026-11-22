# OpenWRT-CI

贝尔040G系列，源ponwrt  
刷机前必须备份所有原厂分区，特别是ri和bosa分区

详细说明  
https://www.right.com.cn/forum/thread-8453612-1-1.html

支持设备： 四个固件通用，设备名称只是区分不同功能 

| 设备 | WAN 定义 | USB 支持 | UBOOT |
| ---- | -------- | -------- | ------ |
| XG-040G-MD | pon0 | USB2 USB3 | ubi |
| XG-040G-TF | pon0 | NA | ubi |

## 恢复MAC地址说明
刷机前必须备份所有原厂分区，特别是ri和bosa分区，参考详细说明刷回备份


## 固件简要说明

固件每天早上5点自动编译。

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

贝尔040系列，140系列。

## 目录简要说明

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置
