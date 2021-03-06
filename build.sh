#!/bin/sh
#------------------------------------------------
#      Centos7 Project Env InstallScript
#      copyright https://oshit.thiszw.com/
#      email: meyer_net@foxmail.com
#------------------------------------------------

FLINK_DIR='/usr/local/opt/flink'

rm -rf src/*.egg-info
rm -rf parts/*
rm -rf eggs/*
rm -rf develop-eggs/*
rm -rf bin/*

if [ ! -f "bootstrap.py" ]; then
    wget -O bootstrap.py https://bootstrap.pypa.io/bootstrap-buildout.py
fi

if [ ! -f "ez_setup.py" ]; then
    wget -O ez_setup.py https://bootstrap.pypa.io/ez_setup.py
fi

python3 bootstrap.py && bin/buildout

ENV_DIR=`pwd`
SANDBOX_FILE=$ENV_DIR/bin/sandbox

function convert_module()
{
    local module_name=$1

    module_path=`find eggs/ -name $module_name-* | awk 'NR==1{print}'`

    local lower_module_name=`echo $module_name | tr '[A-Z]' '[a-z]'`
    mkdir -pv $module_path/$lower_module_name
    mv $module_path/$lower_module_name.py $module_path/$lower_module_name/__init__.py

	return $?
}

if [ -f $SANDBOX_FILE ]; then
    echo "INFO: Start to change environment by file '$SANDBOX_FILE' and 'eggs/*'."
    sed -i "5a  \'$ENV_DIR/src/app\'," $SANDBOX_FILE
    sed -i "s@sys\.path\[0\:0\]@packages@g" $SANDBOX_FILE
    PATH_END_LINE=`awk '/]/ {print NR}' $SANDBOX_FILE | awk 'NR==1{print}'`
    sed -i "$((PATH_END_LINE+1))a sys.path[0:0] = packages" $SANDBOX_FILE
    sed -i "$((PATH_END_LINE+2))a sys.argv.append(packages)" $SANDBOX_FILE

    # six 模块 没有__init__.py
    convert_module "six"
    convert_module "bz2file"
    convert_module "PyHDFS"

    # DJANGO 的包输出到 UWSGI配置中
    # DJANGO + UWSGI + NGX：https://www.cnblogs.com/chenice/p/6921727.html + https://www.cnblogs.com/Erick-L/p/7066455.html
    # cat $SANDBOX_FILE | head -n $PATH_END_LINE | tail -n +1 | awk -F"'" '{print $2}' | uniq | grep -v '^$' | sed "s@$ENV_DIR@pythonpath = $ENV_DIR@g" | xargs -d "\r\n" echo >> src/*.ini

    # 运行命令：根据bin下生成的interpreter指定命名文件，替代原python或python3命令 执行
    $SANDBOX_FILE src/boot.py "$FLINK_DIR/bin/pyflink-stream.sh"
else
    echo "ERROR: Environment by file '$SANDBOX_FILE' build failed."
fi

# 统计UV
# grep "/buffer/" /clouddisk/svr_sync/wwwroot/prj/www/or/buffer.mplus.com/logs/access.log | cut -d " " -f 1 | sort | uniq | wc -l

# 分析日志查看当天的ip连接数
# cat /clouddisk/svr_sync/wwwroot/prj/www/or/buffer.mplus.com/logs/access.log | grep "11/Feb/2018" | awk '{print $1}' | sort | uniq -c | sort -nr

# 3.查看指定的ip在当天究竟访问了什么url
# cat /clouddisk/svr_sync/wwwroot/prj/www/or/buffer.mplus.com/logs/access.log | grep "11/Feb/2018" | grep "192.168.1.111" | awk '{print $7}' | sort | uniq -c | sort -nr

# 4.查看当天访问排行前10的url
# cat /clouddisk/svr_sync/wwwroot/prj/www/or/buffer.mplus.com/logs/access.log | grep "11/Feb/2018" | awk '{print $7}' | sort | uniq -c | sort -nr | head -n 10

# 5.看到指定的ip究竟干了什么
# cat /clouddisk/svr_sync/wwwroot/prj/www/or/buffer.mplus.com/logs/access.log | grep "192.168.1.111" | awk '{print $1"\t"$7}' | sort | uniq -c | sort -nr

# 6.查看访问次数最多的几个分钟(找到热点)
# awk '{print $4}' /clouddisk/svr_sync/wwwroot/prj/www/or/buffer.mplus.com/logs/access.log |cut -c 14-18|sort|uniq -c|sort -nr|head