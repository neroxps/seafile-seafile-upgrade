#！/bin/bash

# 初始化变量
shell_path=$(realpath "$0")
seafile_dir=${shell_path%/*}
if [ ! -L "$seafile_dir/seafile-server-latest" ]; then
    echo "请将本脚本放置于与 seafile-server-latest 同一根目录下，再重新运行本脚本。"
    exit 1
fi
arch=$(uname -m | sed s/"_"/"-"/g)
regexp="http(s?):\/\/[^ \"\(\)\<\>]*seafile-server_[\d\.\_]*$arch.tar.gz"
upgrade_shell_list=/tmp/seafile_upgrade.txt
tmpfile=/tmp/upgrade.txt

# function 版本号大于对比
function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
# function 版本号小于对比
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }

# function 本地版本与官网最新版本对比。
function seafile_new_version_chack() {
    # 获得当前运行版本号
    run_seafile_version=`tail -1 $seafile_dir/seafile-server-latest/seahub/seahub/settings.py | awk -F '"' '{print $2}'`
    echo "从中文官网检查是否存在更新，请稍后......"
    # 检查系统是否安装 wget 与 curl。
    which wget > /dev/null 2>&1
    wget=$?
    which curl > /dev/null  2>&1
    curl=$?
    if [[ $wget -eq 0 ]]; then
        cmd='wget -q https://www.seafile.com/download/ -O -'
    elif [[ $curl -eq 0 ]] ; then
        cmd='curl -Ls https://www.seafile.com/download/'
    else
        echo "本脚本依赖 wget 或 curl，请安装此依赖程序。"
        clean_tmp
        exit 1
    fi
    # 如有多个地址，将在地址列表中找到最新的版本
    addr=($(${cmd} | grep -o -P "$regexp" ))
    max_version=$(echo ${addr[0]} | awk -F '_' '{print $2}')
    for i in ${addr[*]};do
        version=$(echo $i | awk -F '_' '{print $2}')
        if version_gt $version $max_version;then 
            max_version=$i
        fi 
    done
    web_seafile_version=${max_version}

    if [[ $addr == "" ]];then
        echo "无法获得 seafile 最新版下载地址，请检查网络连接是否正常。"
        exit 1
    fi
}

# function 数据库备份
function seafile_mysql_backup() {
    # 获得 seafile 数据库信息，备份用。
    seafile_backup_dir=$seafile_dir"/database" #数据库文件备份路径
    datename=$(date +%Y%m%d-%H-%M-%S)
    file_date=$(date +"%Y-%m-%d-%H-%M-%S")
    mysqlhost=`cat $seafile_dir/conf/ccnet.conf | grep -w HOST |awk '{print $3}'` #mysql ip address
    mysqluser=`cat $seafile_dir/conf/ccnet.conf | grep -w USER |awk '{print $3}'` # seafile 数据库用户名
    mysqlpwd=`cat $seafile_dir/conf/ccnet.conf | grep -w PASSWD |awk '{print $3}'` # seafile 数据库密码
    echo "开始备份 seafile 数据库文件，备份路径：$seafile_backup_dir"
    if [ ! -d $seafile_backup_dir/$datename ]; then
        echo "创建备份目录 $seafile_backup_dir/$datename"
        mkdir -p $seafile_backup_dir/$datename
    fi
    # 备份 ccnet-db
    mysqldump -h $mysqlhost -u$mysqluser -p$mysqlpwd --opt ccnet-db > $seafile_backup_dir/$datename/ccnet-db.sql.$file_date
    if [[ $? > 0 ]]; then
        echo "mysqldump 执行失败，请先手动备份数据库后再使用 seafile_upgrade.sh -no_backup 参数运行升级脚本。"
        exit 1
    elif [ ! -s $seafile_backup_dir/$datename/ccnet-db.sql.$file_date ]; then
        echo "检测到备份文件 $seafile_backup_dir/$datename/ccnet-db.sql.$file_date 为空，为了确保数据安全性，请先手动备份数据库后再使用 seafile_upgrade.sh -no_backup 参数运行升级脚本。"
        exit 1
    fi
    # 备份 seafile-db
    mysqldump -h $mysqlhost -u$mysqluser -p$mysqlpwd --opt seafile-db > $seafile_backup_dir/$datename/seafile-db.sql.$file_date
    if [[ $? > 0 ]]; then
        echo "mysqldump 执行失败，请先手动备份数据库后再使用 seafile_upgrade.sh -no_backup 参数运行升级脚本。"
        exit 1
    elif [ ! -s $seafile_backup_dir/$datename/ccnet-db.sql.$file_date ]; then
        echo "检测到备份文件 $seafile_backup_dir/$datename/seafile-db.sql.$file_date 为空，为了确保数据安全性，请先手动备份数据库后再使用 seafile_upgrade.sh -no_backup 参数运行升级脚本。"
        exit 1
    fi
    # 备份 seahub-db
    mysqldump -h $mysqlhost -u$mysqluser -p$mysqlpwd --opt seahub-db > $seafile_backup_dir/$datename/seahub-db.sql.$file_date
    if [[ $? > 0 ]]; then
        echo "mysqldump 执行失败，请先手动备份数据库后再使用 seafile_upgrade.sh -no_backup 参数运行升级脚本。"
        exit 1
    elif [ ! -s $seafile_backup_dir/$datename/ccnet-db.sql.$file_date ]; then
        echo "检测到备份文件 $seafile_backup_dir/$datename/seahub-db.sql.$file_date 为空，为了确保数据安全性，请先手动备份数据库后再使用 seafile_upgrade.sh -no_backup 参数运行升级脚本。"
        exit 1
    fi
    tar czPf $seafile_dir/database/$datename.tar.gz $seafile_backup_dir/$datename
    rm -rf $seafile_backup_dir/$datename
}

# function 执行升级过程
function upgrade_seafile() {
    if [[ $wget == 0 ]]; then 
        wget $addr -P $seafile_dir
    elif [[ $curl == 0 ]]; then
        curl -o $seafile_dir/$( echo $addr | awk -F/ '{ print $NF }' ) $addr
    else
        echo "本脚本依赖 wget 或 curl，请安装此依赖程序。"
        exit 1
    fi
    file=$seafile_dir"/"$( echo $addr | awk -F/ '{ print $NF }' )
    tar xzf $file -C $seafile_dir
    seafile_path=$( tar tvzf $file 2>/dev/null | head -n 1 | awk '{ print $NF }' | sed -e 's!/!!g')
    web_major_version=${web_seafile_version%.*}
    run_major_version=${run_seafile_version%.*}
    # 保存文件原用户与用户组设置
    seafile_per_user=$(ls -l $seafile_dir | grep -v "grep" | grep -v "latest" | grep -w "seafile-server-$run_seafile_version" | awk '{print $3}')
    seafile_per_group=$(ls -l $seafile_dir | grep -v "grep" | grep -v "latest" | grep -w "seafile-server-$run_seafile_version" | awk '{print $4}')
    if version_gt $web_major_version $run_major_version; then
        # 执行大版本升级脚本
        ## 找到适应当前大版本升级脚本列表
        ls $seafile_dir/$seafile_path/upgrade/ -l |grep -E "upgrade_[0-9].[0-9]_[0-9].[0-9].sh" | awk '{print $9}' > $upgrade_shell_list
        line=`wc -l $upgrade_shell_list | awk '{print $1}'`
        grepsrt="upgrade_"$run_major_version"_[0-9].[0-9].sh"
        linenumber=`grep -En "$grepsrt" $upgrade_shell_list | awk -F ":" '{print $1}'`
        line=`expr $line - $linenumber + 1`
        tail -$line $upgrade_shell_list > $tmpfile
        cat $tmpfile > $upgrade_shell_list
        # 升级前备份
        ## 备份 seafile 运行目录
        if [ ! -d $seafile_dir/installed ]; then
            echo "创建installed目录"
            mkdir $seafile_dir/installed
        fi
        echo "移动 seafile-server-$run_seafile_version 目录到 installed ......"
        mv $seafile_dir/seafile-server-$run_seafile_version $seafile_dir/installed
        echo "开始执行以下升级脚本："
        cat $upgrade_shell_list
        upgrade_shell_line=1
        while (( $line !=0 ))
        do
            upgrade_shell_name=`awk "NR==$upgrade_shell_line" $upgrade_shell_list`
            upgrade_shell_path=$seafile_dir"/"$seafile_path"/upgrade/"$upgrade_shell_name
            echo ""
            echo ""
            echo "###################  $upgrade_shell_name 脚本执行开始  ###################"
            echo | bash $upgrade_shell_path
            if [[ $? > 0 ]]; then
                echo "更新脚本出错，升级脚本退出，你可以从 $seafile_backup_dir 找到最近的数据库备份文件恢复数据库。"
                echo "另某些版本的升级脚本可能会对目录文件操作，请查看 $upgrade_shell_path 脚本修复。"
                echo "你也可以将以上报错信息发送到 https://bbs.seafile.com 论坛进行求助。"
                exit 1
            fi
            echo "###################  $upgrade_shell_name 脚本执行结束  ###################"
            echo ""
            echo ""
            sleep 2
            let "upgrade_shell_line++"
            let "line--"
        done
    else
        # 升级前备份
        ## 备份 seafile 运行目录
        if [ ! -d $seafile_dir/installed ]; then
            echo "创建installed目录"
            mkdir $seafile_dir/installed
        fi
        echo "移动 seafile-server-$run_seafile_version 目录到 installed ......"
        mv $seafile_dir/seafile-server-$run_seafile_version $seafile_dir/installed
        # 执行小版本升级脚本
        echo "执行小版本更新 $seafile_dir/$seafile_path/upgrade/minor-upgrade.sh"
        echo | bash $seafile_dir/$seafile_path/upgrade/minor-upgrade.sh
        if [[ $? > 0 ]]; then
            echo "更新脚本出错，升级脚本退出，你可以从 $seafile_backup_dir 找到最近的数据库备份文件恢复数据库。"
            echo "另某些版本的升级脚本可能会对目录文件操作，请查看 $upgrade_shell_path 脚本修复。"
            echo "你也可以将以上报错信息发送到 https://bbs.seafile.com 论坛进行求助。"
            exit 1
        fi
    fi
    echo "修复权限......"
    chown -R  $seafile_per_user:$seafile_per_group $seafile_dir/seafile-server-$web_seafile_version
    chown -h $seafile_per_user:$seafile_per_group $seafile_dir/seafile-server-latest
    if [[ "$(getenforce)" == "Enforcing" ]]; then
        chcon -R -t httpd_sys_content_t $seafile_dir/seafile-server-latest/seahub
        chcon -R -t httpd_sys_content_t $seafile_dir/seahub-data
        chcon -R -t httpd_sys_content_t $seafile_dir/seafile-server-latest
    fi
    echo "权限修复完毕。"
}

# function 清除临时文件
function clean_tmp() {
    if [ -f $file ]; then rm -f $file; fi
    if [ -f $tmpfile ]; then rm -f $tmpfile; fi
    if [ -f $upgrade_shell_list ]; then rm -f $upgrade_shell_list; fi
}

# function 启动或停止 seafile
function seafile_control() {
    if [[ "$1" == "stop" ]]; then
        manage_py="$seafile_dir/seafile-server-$run_seafile_version/seahub/manage.py"
        default_ccnet_conf_dir="$seafile_dir/ccnet"
        if  pgrep -f "seafile-controller" 2>/dev/null 1>&2 ; then
            # 记录是否以 fastcgi 启动 seahub，留给后续重启 seahub 用。
            ps aux | grep -v "grep" | grep -q -w "runfcgi"
            fastcgi=$?
            # 记录 seahub 的启动端口
            seafile_port=$(ps aux | grep seahub | head -n1 |grep -oE "port=.*" | awk '{print $1}' | awk -F "=" '{print $2}')
            if [[ "$seafile_port" == "" ]]; then
                seafile_port=$(ps aux | grep seahub | grep -oE '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}:[[:digit:]]{1,4}' | head -n1 | awk -F ":" '{print $2}')
            fi
        else
            echo "未检测到 seafile 运行，请输入 seahub 的运行模式和运行端口。"
            while true; do
                read -r -p "seahub 是否以 fastcgi 启动？(Yes/No)[No]:" input
                case $input in
                    [yY][eE][sS]|[yY])
                        fastcgi=0
                        break 1
                        ;;
                    [nN][oO]|[nN]|"")
                        fastcgi=1
                        break 1
                        ;;
                    *)
                        echo "输入有误，请重新输入。"
                esac
            done
            read -r -p "请输入 seahub 端口号 [默认8000]:" seafile_port
            if [[ "$seafile_port" == "" ]]; then
                seafile_port="8000"
            fi
        fi
    fi

    # 检查是否支持 systemctl 方式控制，若失败则以传统脚本方式启动。
    if systemctl list-unit-files --type=service | grep -w -q "seafile.service" && \
    systemctl list-unit-files --type=service | grep -w -q "seafile.service"; then
        systemctl $1 seafile.service > /dev/null 2>&1
        systemctl $1 seahub.service > /dev/null 2>&1
    elif  systemctl list-unit-files --type=service | grep -w -q "seafile.service"; then
        systemctl $1 seafile.service > /dev/null 2>&1
    elif systemctl list-unit-files --type=service | grep -w -q "seahub.service"; then
        systemctl $1 seahub.service > /dev/null 2>&1
    elif systemctl list-unit-files --type=service | grep -w -q "seafile-server.service"; then
        systemctl $1 seafile-server.service > /dev/null 2>&1
    else
        if [[ "$1" == "stop" ]]; then
            bash $seafile_dir/seafile-server-latest/seafile.sh $1
            bash $seafile_dir/seafile-server-latest/seahub.sh $1
        elif [[ "$1" == "start" && $fastcgi == 0 ]]; then
            su $seafile_per_user  bash $seafile_dir/seafile-server-latest/seafile.sh $1
            su $seafile_per_user  bash $seafile_dir/seafile-server-latest/seahub.sh $1-fastcgi $seafile_port
        else
            su $seafile_per_user bash $seafile_dir/seafile-server-latest/seafile.sh $1
            su $seafile_per_user bash $seafile_dir/seafile-server-latest/seahub.sh $1 $seafile_port
        fi
    fi

    # 检查 seafile 是否正常结束运行
    if [[ "$1" == "stop" ]]; then
        if pgrep -f $manage_py 2>/dev/null 1>&2; then
            echo "停止 seahub 失败，为了升级正常进行，使用结束进程方式停止 seahub......"
            pgrep -f $manage_py | xargs kill
        fi
        if pgrep -f "seafile-controller" 2>/dev/null 1>&2; then
            echo "停止 seafile 失败，为了升级正常进行，使用结束进程方式停止 seafile......"
            pkill -SIGTERM -f "seafile-controller -c ${default_ccnet_conf_dir}"
            pkill -f "ccnet-server -c ${default_ccnet_conf_dir}"
            pkill -f "seaf-server -c ${default_ccnet_conf_dir}"
            pkill -f "fileserver -c ${default_ccnet_conf_dir}"
            pkill -f "soffice.*--invisible --nocrashreport"
            pkill -f  "wsgidav.server.run_server"
        fi
        rm -f ${seafile_dir}/pids/*
    fi
}

function refresh_cache () {
    if [[ $(grep -w "CACHES = {" $seafile_dir/conf/seahub_settings.py | wc -l) > 0 ]]; then
        systemctl restart memcached > /dev/null 2>&1
        if [[ $? > 0 ]]; then echo "重启 memcached 失败，请检查 web 是否正常，如显示”Page unavailable”请手动重启 memcached。"; fi
    fi
    if [ -d /tmp/seahub_cache ]; then rm -rf /tmp/seahub_cache; fi
}

# main
par="$@"

# 调用版本检查方法，此方法会初始化 $addr 变量，获得 seafile 新版版本下载路径。
seafile_new_version_chack
# $web_seafile_version 为官网最新的版本，$run_seafile_version 为当前 seafile 运行版本

# 检查 seafile 当前运行版本符合本脚本最低版本要求。
if version_lt $run_major_version "5.0.0"; then
    echo "检测到 seafile 版本低于 seafile 5.0.0，超出本脚本支持版本。"
    exit 1
fi

# 确认升级操作
echo "当前 seafile 版本为：$run_seafile_version"
echo "检测到 seafile 新版本： $web_seafile_version"
if [[ "$run_seafile_version" == "$web_seafile_version" ]]; then
    echo "您的 seafile 版本为最新的，无需升级。"
    echo "升级脚本结束，Bay!"
    exit 0
fi
echo "在你确定升级前，请阅读 seafile 更新日志 https://manual.seafile.com/changelog/server-changelog.html，新版本有可能需要安装新的依赖，本脚本不会自动安装依赖。"
while true
do
    read -r -p "是否确定升级？(Yes/No)[Y]:" input
    case $input in
        [yY][eE][sS]|[yY]|"")
                    echo "开始进入升级过程....."
                    break 1
                    ;;
        [nN][oO]|[nN])
                    clean_tmp
                    echo "结束更新脚本，Bay！"
                    exit 0
                    ;;
        *)
                    echo "错误输入，请输入正确指令"
                    ;;
    esac
done

echo "停止 seafile 服务......"
seafile_control stop

# 默认备份 seafile 数据库。
echo $par | grep -q -w "\-no_backup"
if [[ $? > 0 ]]; then seafile_mysql_backup; fi

echo "开始升级 seafile......"
upgrade_seafile
echo "刷新 web 缓存......"
refresh_cache
echo "启动 seafile 服务......"
seafile_control start
echo "seafile 升级完毕,bay!"
clean_tmp
exit 0
