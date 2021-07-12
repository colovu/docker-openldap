#!/bin/bash
# Ver: 1.3 by Endial Fang (endial@126.com)
# 
# 应用启动脚本

# 设置 shell 执行参数，可使用'-'(打开）'+'（关闭）控制。常用：
# 	-e: 命令执行错误则报错(errexit); -u: 变量未定义则报错(nounset); -x: 打印实际待执行的命令行; -o pipefail: 设置管道中命令遇到失败则报错
set -eu
set -o pipefail

. /usr/local/bin/common.sh				# 应用专用函数库
. /usr/local/bin/environment.sh 		# 设置环境变量

LOG_I "** Processing run.sh **"

# Reduce maximum number of open file descriptors
# https://github.com/docker/docker/issues/8231
ulimit -n "$LDAP_ULIMIT_NOFILES"

readonly START_COMMAND="$(command -v ${APP_EXEC})"

flags=("-h" "ldap://:${LDAP_PORT_NUMBER}/ ldapi:///")
# 如果启用 TLS, 增加 LDAPS 服务
is_boolean_yes "$LDAP_ENABLE_TLS" && flags=("-h" "ldap://:${LDAP_PORT_NUMBER}/ ldaps://:${LDAP_LDAPS_PORT_NUMBER}/ ldapi:///")

# 确保应用运行在前台
flags=("-d" "stats" "${flags[@]}")
flags=("-F" "${APP_CONF_DIR}/slapd.d" "${flags[@]}")

[[ -z "${APP_EXTRA_FLAGS:-}" ]] || flags=("${flags[@]}" "${APP_EXTRA_FLAGS[@]}")
# 增加 "@" 以使用用户在命令行添加的扩展标识
flags=("${flags[@]}" "$@")

LOG_I "** Starting ${APP_NAME} **"
is_root && flags=("-u" "$LDAP_DAEMON_USER" "${flags[@]}")

LOG_I "Command: ${START_COMMAND[@]} ${flags[@]}"
exec "${START_COMMAND[@]}" "${flags[@]}"
