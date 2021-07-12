#!/bin/bash -e
# Ver: 1.1 by Endial Fang (endial@126.com)
#
# 在安装完应用后，使用该脚本修改默认配置文件中部分配置项; 如果相应的配置项已经定义为容器环境变量，则不需要在这里修改

# 定义要修改的文件(改文件应当是默认配置文件目录中的模板文件)
CONF_FILE="${APP_DEF_DIR}/config/server.properties"

echo "Process overrides for: ${CONF_FILE}"
#sed -i -E 's/^#?listeners=/d' "${CONF_FILE}"
#sed -i -E 's/^#?log.dirs=\/tmp\/kafka-logs*/log.dirs=\/var\/log\/kafka/g' "${CONF_FILE}"
