# OpenWRT-CI

贝尔040G系列，全面升级6.18内核  
刷机前必须备份所有原厂分区，特别是ri和bosa分区

详细说明  
https://www.right.com.cn/forum/thread-8453612-1-1.html

支持设备： 四个固件通用，设备名称只是区分不同功能 

带USB设备:
  XG-040G-MD  XG-140G-MD(lan4 wan)

不带USB设备: 
  XG-040G-TF  XG-140G-TF(lan4 wan)

https://github.com/bingoguo93/immortalwrt.git

# 恢复MAC地址说明
刷机前必须备份所有原厂分区，特别是ri和bosa分区（以下为040-MD的分区）
mtd6: 00040000 00020000 "bosa"
mtd7: 00040000 00020000 "ri"
备份命令

dd if=/dev/mtd6 of=/mnt/Ventoy/mtd6.bin
dd if=/dev/mtd7 of=/mnt/Ventoy/mtd7.bin
恢复光校准和MAC地址，将ri和bosa分区上传到/tmp目录
查看
#ubinfo -a
显示以下内容，
Volume ID:   0 (on ubi0)
Type:        dynamic
Alignment:   1
Size:        9 LEBs (1142784 bytes, 1.0 MiB)
State:       OK
Name:       bosa

Volume ID:   1 (on ubi0)
Type:        dynamic
Alignment:   1
Size:        9 LEBs (1142784 bytes, 1.0 MiB)
State:       OK
Name:        ri
Character device major/minor: 252:2

刷入命令
ubiupdatevol /dev/ubi0_0 /tmp/mtd6.bin
ubiupdatevol /dev/ubi0_1 /tmp/mtd7.bin
执行完成重启

# 固件简要说明

固件每天早上5点自动编译。

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

贝尔040系列，140系列。

# 目录简要说明

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置
