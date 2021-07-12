#!/bin/bash
# Ver: 1.0 by Endial Fang (endial@126.com)
# 
# 应用环境变量定义及初始化

# 通用设置
export ENV_DEBUG=${ENV_DEBUG:-false}
export ALLOW_ANONYMOUS_LOGIN="${ALLOW_ANONYMOUS_LOGIN:-no}"

# 通过读取变量名对应的 *_FILE 文件，获取变量值；如果对应文件存在，则通过传入参数设置的变量值会被文件中对应的值覆盖
# 变量优先级： *_FILE > 传入变量 > 默认值
app_env_file_lists=(
	APP_PASSWORD
)
for env_var in "${app_env_file_lists[@]}"; do
    file_env_var="${env_var}_FILE"
    if [[ -n "${!file_env_var:-}" ]]; then
        export "${env_var}=$(< "${!file_env_var}")"
        unset "${file_env_var}"
    fi
done
unset app_env_file_lists

# 应用路径参数
export APP_HOME_DIR="/usr/local"
export APP_DEF_DIR="/etc/${APP_NAME}"
export APP_CONF_DIR="/srv/conf/${APP_NAME}"
export APP_DATA_DIR="/srv/data/${APP_NAME}"
export APP_DATA_LOG_DIR="/srv/datalog/${APP_NAME}"
export APP_CACHE_DIR="/var/cache/${APP_NAME}"
export APP_RUN_DIR="/var/run/${APP_NAME}"
export APP_LOG_DIR="/var/log/${APP_NAME}"
export APP_CERT_DIR="/srv/cert/${APP_NAME}"

# 应用配置参数
export LDAP_PORT_NUMBER="${LDAP_PORT_NUMBER:-8389}"
export LDAP_LDAPS_PORT_NUMBER="${LDAP_LDAPS_PORT_NUMBER:-8636}"

export LDAP_EXTRA_SCHEMAS="${LDAP_EXTRA_SCHEMAS:-cosine,inetorgperson,nis}"
export LDAP_EXTRA_MODULES="${LDAP_EXTRA_MODULES:-accesslog}"

export LDAP_CUSTOM_LDIF_DIR="${LDAP_CUSTOM_LDIF_DIR:-initdb.d/ldifs}"
export LDAP_CUSTOM_SCHEMA_DIR="${LDAP_CUSTOM_SCHEMA_FILE:-initdb/schema}"

export LDAP_ULIMIT_NOFILES="${LDAP_ULIMIT_NOFILES:-1024}"

export LDAP_ENABLE_TLS="${LDAP_ENABLE_TLS:-no}"
export LDAP_TLS_CERT_FILE="${LDAP_TLS_CERT_FILE:-}"
export LDAP_TLS_KEY_FILE="${LDAP_TLS_KEY_FILE:-}"
export LDAP_TLS_CA_FILE="${LDAP_TLS_CA_FILE:-}"
export LDAP_TLS_DH_PARAMS_FILE="${LDAP_TLS_DH_PARAMS_FILE:-}"

export LDAP_ROOT="${LDAP_ROOT:-dc=example,dc=org}"
export LDAP_ORGNIZATION_NAME="${LDAP_ORGNIZATION_NAME:-Colovu Lab}"

export LDAP_ROOT_USERNAME="${LDAP_ROOT_USERNAME:-root}"
export LDAP_ROOT_DN="${LDAP_ROOT_USERNAME/#/cn=},${LDAP_ROOT}"
export LDAP_ROOT_PASSWORD="${LDAP_ROOT_PASSWORD:-rootpassword}"

export LDAP_BIND_GIVEN_NAME="${LDAP_BIND_GIVEN_NAME:-Binder}"
export LDAP_BIND_SURNAME="${LDAP_BIND_SURNAME:-UAC}"
export LDAP_BIND_UID="${LDAP_BIND_UID:-bind}"
export LDAP_BIND_DN="${LDAP_BIND_UID/#/uid=},ou=Manager,${LDAP_ROOT}"
export LDAP_BIND_PASSWORD="${LDAP_BIND_PASSWORD:-bindpassword}"

export LDAP_ADMIN_GIVEN_NAME="${LDAP_ADMIN_GIVEN_NAME:-Administrator}"
export LDAP_ADMIN_SURNAME="${LDAP_ADMIN_SURNAME:-UAC}"
export LDAP_ADMIN_UID="${LDAP_ADMIN_UID:-admin}"
export LDAP_ADMIN_DN="${LDAP_ADMIN_UID/#/uid=},ou=Manager,${LDAP_ROOT}"
export LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-adminpassword}"
export LDAP_ADMIN_MAIL="${LDAP_ADMIN_MAIL:-admin@example.com}"

export LDAP_USERS="${LDAP_USERS:-user01,user02}"
export LDAP_PASSWORDS="${LDAP_PASSWORDS:-password1,password2}"
export LDAP_USER_OU="${LDAP_USER_OU:-users}"
export LDAP_USER_GROUP="${LDAP_USER_GROUP:-readers}"

export LDAP_SKIP_DEFAULT_TREE="${LDAP_SKIP_DEFAULT_TREE:-no}"

# 内部变量
export LDAP_ONLINE_CONF_DIR="${APP_CONF_DIR}/slapd.d"
export LDAP_PID_FILE="${APP_RUN_DIR}/slapd.pid"
export LDAP_ARGS_FILE="${APP_RUN_DIR}/slapd.args"

export LDAP_DAEMON_USER="slapd"
export LDAP_DAEMON_GROUP="slapd"

export LDAP_ENCRYPTED_ROOT_PASSWORD="$(echo -n $LDAP_ROOT_PASSWORD | slappasswd -n -T /dev/stdin)"
export LDAP_ENCRYPTED_BIND_PASSWORD="$(echo -n $LDAP_BIND_PASSWORD | slappasswd -n -T /dev/stdin)"
export LDAP_ENCRYPTED_ADMIN_PASSWORD="$(echo -n $LDAP_ADMIN_PASSWORD | slappasswd -n -T /dev/stdin)"

# 个性化变量

