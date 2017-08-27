# seafile-server-upgrade
seafile 升级一键脚本，自动检测官网最新版本并下载升级到最新版。

# 脚本简介
* 最低支持 seafile 5.0.0 以上版本 （由于 seafile 5.0 开始修改了配置文件存放地，并4.x 版本已经差不多一年前，不打算适配）
* 自动备份数据库文件到 seafile 程序目录的 database 目录下
* 理论上适配 Ubuntu 16.04、Debian 9、CentOS 7（已测试通过）
* 支持 systemctl 启动方式，如无配置 systemctl，脚本会自动识别使用 seafile 官方启动脚本停止或启动 seafile

# 使用方法
1. 
