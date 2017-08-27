# seafile-server-upgrade
seafile 升级一键脚本，自动检测官网最新版本并下载升级到最新版。
升级前建议到查看下[版本更新日志](https://manual.seafile.com/changelog/server-changelog.html)，有可能加入新的依赖，本脚本不会解决依赖，只会运行 seafile 升级脚本。

# 脚本简介
* 最低支持 seafile 5.0.0 或以上版本 （由于 seafile 5.0 开始修改了配置文件存放地，并4.x 版本已经差不多一年前，不打算适配）。
* 自动备份升级前的数据库文件到 seafile 程序目录的 database 目录下，以时间命名。
* 理论上适配 Ubuntu 16.04、Debian 9、CentOS 7（已测试通过）。
* 支持 systemctl 启动方式，如无配置 systemctl，脚本会自动识别使用 seafile 官方启动脚本停止或启动 seafile。
* 自动识别大版本或小版本升级。

# 使用方法
1. 下载脚本到 seafile 程序目录
```
cd /opt/seafile
wget https://raw.githubusercontent.com/neroxps/seafile-server-upgrade/master/seafile_upgrade.sh
```

2. 使用 root 权限运行脚本
```
sudo chmod +x seafile_upgrade.sh
sudo ./seafile_upgrade.sh
```

# 故障处理
按照正常部署的 seafile 升级不大可能会遇到错误，但遇到错误不需要慌，脚本会自动备份好升级前的数据库，您只需要将数据库恢复，将在 installed 目录下的 `seafile-server-*.*.*（升级前的版本号）`目录迁移会 seafile 程序目录，修复 seafile-server-latest 软连接即可恢复。

另你也可以将升级脚本的错误发到[seafile 论坛](https://bbs.seafile.com) 集群众之力一齐解决吧？
