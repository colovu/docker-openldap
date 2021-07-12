#!/bin/bash
# Ver: 1.1 by Endial Fang (endial@126.com)
# 
# 应用通用业务处理函数

# 加载依赖脚本
. /usr/local/scripts/libcommon.sh       # 通用函数库

. /usr/local/scripts/libfile.sh
. /usr/local/scripts/libfs.sh
. /usr/local/scripts/liblog.sh
. /usr/local/scripts/libos.sh
. /usr/local/scripts/libservice.sh
. /usr/local/scripts/libvalidations.sh

# 函数列表

# 使用环境变量中配置，更新配置文件
openldap_update_conf() {
    LOG_I "Update configure files..."

}

# 生成RootDN用户信息
openldap_root_credentials() {
    # 根据容器参数，设置配置文件
    LOG_I "Configure LDAP credentials for RootDN"

cat > "${APP_CONF_DIR}/rootdn.ldif" << EOF
# RootDN configration
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: $LDAP_ROOT

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: $LDAP_ROOT_DN

dn: olcDatabase={2}hdb,cn=config
add: olcRootPW
olcRootPW: $LDAP_ENCRYPTED_ROOT_PASSWORD

dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=$(id -u),cn=peercred,cn=external, cn=auth" read 
    by dn.base="${LDAP_ADMIN_DN}" read 
    by * none
EOF

    debug_execute ldapmodify -Y EXTERNAL -H "ldapi:///" -f "${APP_CONF_DIR}/rootdn.ldif"
}

openldap_add_default_policy() {
# 根据容器参数，设置配置文件
    LOG_I "Add default global access control policy"

cat > "${APP_CONF_DIR}/default_policy.ldif" << EOF
# Add default global access control policy
dn: olcDatabase={-1}frontend,cn=config
changetype: modify
replace: olcAccess
olcAccess: to attrs="userPassword,sambaLMPassword,sambaNTPassword,sambaPwdLastSet,sambaPwdMustChange,sambaPwdCanChange,shadowMax,shadowExpire" 
    by dn.base="gidNumber=0+uidNumber=$(id -u),cn=peercred,cn=external,cn=auth" manage 
    by dn.base="${LDAP_BIND_DN}" read 
    by dn.base="${LDAP_ADMIN_DN}" write 
    by anonymous auth 
    by self write 
    by * none

dn: olcDatabase={-1}frontend,cn=config
changetype: modify
replace: olcAccess
olcAccess: to * 
    by dn.base="gidNumber=0+uidNumber=$(id -u),cn=peercred,cn=external,cn=auth" manage 
    by dn.base="${LDAP_BIND_DN}" read 
    by dn.base="${LDAP_ADMIN_DN}" write 
    by anonymous auth 
    by self write 
    by * none

EOF

    debug_execute ldapmodify -Y EXTERNAL -H "ldapi:///" -f "${APP_CONF_DIR}/default_policy.ldif"
}

# 生成Admin账户用户信息
openldap_create_tree() {
    # 根据容器参数，设置配置文件
    LOG_I "Configure LDAP credentials for admin user"

cat > "${APP_CONF_DIR}/admin.ldif" << EOF
# RootDN creation
dn: $LDAP_ROOT
objectClass: dcObject
objectClass: organization
o: $LDAP_ORGNIZATION_NAME

# Mnanger OU creation
dn: ou=Manager,$LDAP_ROOT
objectClass: organizationalUnit
ou: Manager

# User Admin creation
dn: uid=$LDAP_ADMIN_UID,ou=Manager,$LDAP_ROOT
objectClass: inetOrgPerson
cn: $LDAP_ADMIN_GIVEN_NAME $LDAP_ADMIN_SURNAME
sn: $LDAP_ADMIN_SURNAME
uid: $LDAP_ADMIN_UID
userPassword: $LDAP_ENCRYPTED_ADMIN_PASSWORD
mail: $LDAP_ADMIN_MAIL

# User Binder creation
dn: uid=$LDAP_BIND_UID,ou=Manager,$LDAP_ROOT
objectClass: inetOrgPerson
cn: $LDAP_BIND_GIVEN_NAME $LDAP_BIND_SURNAME
sn: $LDAP_BIND_SURNAME
uid: $LDAP_BIND_UID
userPassword: $LDAP_ENCRYPTED_BIND_PASSWORD
EOF

    debug_execute ldapadd -f "${APP_CONF_DIR}/admin.ldif" -H "ldapi:///" -D "$LDAP_ROOT_DN" -w "$LDAP_ROOT_PASSWORD"

    openldap_add_default_policy
}

# 生成自定义账户用户信息
openldap_create_users() {
    # 根据容器参数，设置配置文件
    LOG_I "Configure LDAP credentials for admin user"

cat > "${APP_CONF_DIR}/users.ldif" << EOF
# User OU creation
dn: ${LDAP_USER_OU/#/ou=},$LDAP_ROOT
objectClass: organizationalUnit
ou: users

EOF

    read -r -a users <<< "$(tr ',;' ' ' <<< "${LDAP_USERS}")"
    read -r -a passwords <<< "$(tr ',;' ' ' <<< "${LDAP_PASSWORDS}")"

    local index=0
    for user in "${users[@]}"; do
        cat >> "${APP_CONF_DIR}/users.ldif" << EOF
# User $user creation
dn: ${user/#/cn=},${LDAP_USER_OU/#/ou=},${LDAP_ROOT}
cn: User$((index + 1 ))
sn: Bar$((index + 1 ))
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
userPassword: ${passwords[$index]}
uid: $user
uidNumber: $((index + 1000 ))
gidNumber: $((index + 1000 ))
homeDirectory: /home/${user}

EOF
        index=$((index + 1 ))
    done
    
    cat >> "${APP_CONF_DIR}/users.ldif" << EOF
# Group creation
dn: ${LDAP_USER_GROUP/#/cn=},${LDAP_USER_OU/#/ou=},${LDAP_ROOT}
cn: $LDAP_USER_GROUP
objectClass: groupOfNames
# User group membership
EOF

    for user in "${users[@]}"; do
        cat >> "${APP_CONF_DIR}/users.ldif" << EOF
member: ${user/#/cn=},${LDAP_USER_OU/#/ou=},${LDAP_ROOT}
EOF
    done

    debug_execute ldapadd -f "${APP_CONF_DIR}/users.ldif" -H "ldapi:///" -D "$LDAP_ROOT_DN" -w "$LDAP_ROOT_PASSWORD"
}

# 生成默认配置文件
openldap_generate_conf() {
    # 根据容器参数，设置配置文件
    LOG_I "Creating LDAP online configuration"

    ! is_root && replace_in_file "${APP_CONF_DIR}/slapd.ldif" "uidNumber=0" "uidNumber=$(id -u)"
    debug_execute slapadd -F "$LDAP_ONLINE_CONF_DIR" -n 0 -l "${APP_CONF_DIR}/slapd.ldif"
}

# 生成LTS配置文件
openldap_generate_lts_conf() {
    LOG_I "Configuring TLS"

    cat > "${APP_CONF_DIR}/certs.ldif" << EOF
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: $LDAP_TLS_CA_FILE
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: $LDAP_TLS_CERT_FILE
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: $LDAP_TLS_KEY_FILE
EOF

    if [[ -f "$LDAP_TLS_DH_PARAMS_FILE" ]]; then
        cat >> "${APP_CONF_DIR}/certs.ldif" << EOF
-
replace: olcTLSDHParamFile
olcTLSDHParamFile: $LDAP_TLS_DH_PARAMS_FILE
EOF
    fi
    debug_execute ldapmodify -Y EXTERNAL -H "ldapi:///" -f "${APP_CONF_DIR}/certs.ldif"

}

# 检测用户参数信息是否满足条件; 针对部分权限过于开放情况，打印提示信息
openldap_verify_minimum_env() {
    local error_code=0

    LOG_D "Validating settings in APP_* env vars..."

    print_validation_error() {
        LOG_E "$1"
        error_code=1
    }

    check_allowed_port() {
        local port_var="${1:?missing port variable}"
        local validate_port_args=()
        ! is_root && validate_port_args+=("-unprivileged")
        if ! err=$(validate_port "${validate_port_args[@]}" "${!port_var}"); then
            print_validation_error "An invalid port was specified in the environment variable ${port_var}: ${err}."
        fi
    }
    
    for var in LDAP_SKIP_DEFAULT_TREE LDAP_ENABLE_TLS; do
        if ! is_yes_no_value "${!var}"; then
            print_validation_error "The allowed values for $var are: yes or no"
        fi
    done

    if is_boolean_yes "$LDAP_ENABLE_TLS"; then
        if [[ -z "$LDAP_TLS_CERT_FILE" ]]; then
            print_validation_error "You must provide a X.509 certificate in order to use TLS"
        elif [[ ! -f "$LDAP_TLS_CERT_FILE" ]]; then
            print_validation_error "The X.509 certificate file in the specified path ${LDAP_TLS_CERT_FILE} does not exist"
        fi
        if [[ -z "$LDAP_TLS_KEY_FILE" ]]; then
            print_validation_error "You must provide a private key in order to use TLS"
        elif [[ ! -f "$LDAP_TLS_KEY_FILE" ]]; then
            print_validation_error "The private key file in the specified path ${LDAP_TLS_KEY_FILE} does not exist"
        fi
        if [[ -z "$LDAP_TLS_CA_FILE" ]]; then
            print_validation_error "You must provide a CA X.509 certificate in order to use TLS"
        elif [[ ! -f "$LDAP_TLS_CA_FILE" ]]; then
            print_validation_error "The CA X.509 certificate file in the specified path ${LDAP_TLS_CA_FILE} does not exist"
        fi
    fi

    read -r -a users <<< "$(tr ',;' ' ' <<< "${LDAP_USERS}")"
    read -r -a passwords <<< "$(tr ',;' ' ' <<< "${LDAP_PASSWORDS}")"
    if [[ "${#users[@]}" -ne "${#passwords[@]}" ]]; then
        print_validation_error "Specify the same number of passwords on LDAP_PASSWORDS as the number of users on LDAP_USERS!"
    fi

    if [[ -n "$LDAP_PORT_NUMBER" ]] && [[ -n "$LDAP_LDAPS_PORT_NUMBER" ]]; then
        if [[ "$LDAP_PORT_NUMBER" -eq "$LDAP_LDAPS_PORT_NUMBER" ]]; then
            print_validation_error "LDAP_PORT_NUMBER and LDAP_LDAPS_PORT_NUMBER are bound to the same port!"
        fi
    fi
    [[ -n "$LDAP_PORT_NUMBER" ]] && check_allowed_port LDAP_PORT_NUMBER
    [[ -n "$LDAP_LDAPS_PORT_NUMBER" ]] && check_allowed_port LDAP_LDAPS_PORT_NUMBER

    [[ "$error_code" -eq 0 ]] || exit "$error_code"
}

# 以后台方式启动应用服务，并等待启动就绪
openldap_start_server_bg() {
    local -a flags=("-h" "ldap://:${LDAP_PORT_NUMBER}/ ldapi:/// " "-F" "${APP_CONF_DIR}/slapd.d")
    local -r command="$(command -v slapd)"

    if openldap_is_server_not_running; then

        LOG_I "Starting ${APP_NAME} in background..."
        LOG_D "${command} ${flags[@]}"

        ulimit -n "$LDAP_ULIMIT_NOFILES"

        is_root && flags=("-u" "$LDAP_DAEMON_USER" "${flags[@]}")
        debug_execute ${command} "${flags[@]}"
        
    	# 通过命令或特定端口检测应用是否就绪
        LOG_D "Checking ${APP_NAME} ready status..."
        # wait-for-port --timeout 60 "$ZOO_PORT_NUMBER"

        LOG_I "${APP_NAME} is ready for service..."
    fi
}

# 停止应用服务
openldap_stop_server() {
    local -r retries="${1:-10}"
    local -r sleep_time="${2:-1}"

    if openldap_is_server_running ; then
	    LOG_I "Stopping ${APP_NAME}..."
    
	    # 使用 PID 文件 kill 进程
	    stop_service_using_pid "$LDAP_PID_FILE"

		# 检测停止是否完成
	    while [[ "$retries" -ne 0 ]] && openldap_is_server_running; do
	        LOG_D "Waiting for ${APP_NAME} to stop..."
	        sleep ${sleep_time}
	        retries=$((retries - 1))
	    done
	else 
        LOG_D "${APP_NAME} stopped..."
    fi
}

# 检测应用服务是否在后台运行中
openldap_is_server_running() {
    LOG_D "Check if ${APP_NAME} is running..."
    local pid
    pid="$(get_pid_from_file "${LDAP_PID_FILE}")"
    LOG_D "${APP_NAME} PID: ${pid}"

    if [[ -n "${pid}" ]]; then
        is_service_running "${pid}"
    else
        false
    fi
}

openldap_is_server_not_running() {
    ! openldap_is_server_running
}

# 增加 schema 文件
openldap_add_modules() {
    LOG_I "Adding LDAP extra modules"

    #read -r -a modules <<< "$(tr ',;' ' ' <<< "${LDAP_EXTRA_MODULES}")"
    modules=($(echo "${LDAP_EXTRA_MODULES[*]} accesslog" | tr ',;' ' ' | sed 's/ /\n/g' | sort | uniq) )
    cat > "${APP_CONF_DIR}/modules.ldif" << EOF
dn: cn=module{0},cn=config
add: olcModuleLoad
EOF

    for module in "${modules[@]}"; do
        LOG_D "Add module: ${module}.la"
        cat >> "${APP_CONF_DIR}/modules.ldif" << EOF
olcModuleLoad: ${module}.la
EOF
        debug_execute ldapmodify -Y EXTERNAL -H "ldapi:///" -f "${APP_CONF_DIR}/modules.ldif"
    done
}

# 增加 schema 文件
openldap_add_schemas() {
    LOG_I "Adding LDAP extra schemas"

    #read -r -a schemas <<< "$(tr ',;' ' ' <<< "${LDAP_EXTRA_SCHEMAS}")"
    schemas=($(echo "${LDAP_EXTRA_SCHEMAS[*]} cosine inetorgperson nis samba" | tr ',;' ' ' | sed 's/ /\n/g' | sort | uniq) )
    for schema in "${schemas[@]}"; do
        LOG_D "Add schema: ${schema}.ldif"
        debug_execute ldapadd -Y EXTERNAL -H "ldapi:///" -f "${APP_CONF_DIR}/schema/${schema}.ldif"
    done
}

# 增加个性化 schema 文件
openldap_add_custom_schema() {
    LOG_I "Adding custom Schema in $LDAP_CUSTOM_SCHEMA_DIR ..."

    #find "$LDAP_CUSTOM_SCHEMA_DIR" -maxdepth 1 \( -type f -o -type l \) -iname '*.ldif' -print0 | sort -z | xargs --null -I{} bash -c ". /usr/local/scripts/libos.sh && debug_execute debug_execute slapadd -F "$LDAP_ONLINE_CONF_DIR" -n 0 -l {} "
    find "${APP_CONF_DIR}/${LDAP_CUSTOM_SCHEMA_DIR}" -maxdepth 1 \( -type f -o -type l \) -iname '*.ldif' -print0 | sort -z | while read -r f; do
        LOG_D "Add schema: ${schema}.ldif"
        debug_execute debug_execute slapadd -F "$LDAP_ONLINE_CONF_DIR" -n 0 -l $f
    done
    
    openldap_stop_server
    #while openldap_is_server_running; do sleep 1; done
    openldap_start_server_bg
}

# 导入 ldif 文件定义的数据
openldap_add_custom_ldifs() {
    LOG_I "Loading custom LDIF files..."
    LOG_W "Ignoring LDAP_USERS, LDAP_PASSWORDS, LDAP_USER_OU and LDAP_USER_GROUP environment variables..."
    
    #find "$LDAP_CUSTOM_LDIF_DIR" -maxdepth 1 \( -type f -o -type l \) -iname '*.ldif' -print0 | sort -z | xargs --null -I{} bash -c ". /usr/local/scripts/libos.sh && debug_execute ldapadd -f {} -H 'ldapi:///' -D $LDAP_ROOT_DN -w $LDAP_ROOT_PASSWORD"
    find "${APP_CONF_DIR}/${LDAP_CUSTOM_LDIF_DIR}" -maxdepth 1 \( -type f -o -type l \) -iname '*.ldif' -print0 | sort -z | while read -r f; do
        LOG_D "Add ldif: ${schema}.ldif"
        debug_execute ldapadd -f $f -H 'ldapi:///' -D $LDAP_ROOT_DN -w $LDAP_ROOT_PASSWORD
    done
}

# 清理初始化应用时生成的临时文件
openldap_clean_tmp_file() {
    LOG_D "Clean ${APP_NAME} tmp files for init..."

}

# 在重新启动容器时，删除标志文件及必须删除的临时文件 (容器重新启动)
openldap_clean_from_restart() {
    LOG_D "Clean ${APP_NAME} tmp files for restart..."
    local -r -a files=(
        "/var/run/${APP_NAME}/${APP_NAME}.pid"
    )

    for file in ${files[@]}; do
        if [[ -f "$file" ]]; then
            LOG_I "Cleaning stale $file file"
            rm "$file"
        fi
    done
}

# 应用默认初始化操作
# 执行完毕后，生成文件 ${APP_CONF_DIR}/.app_init_flag 及 ${APP_DATA_DIR}/.data_init_flag 文件
openldap_default_init() {
	openldap_clean_from_restart
    LOG_D "Check init status of ${APP_NAME}..."

    # 检测配置文件是否存在
    if [[ ! -f "${APP_CONF_DIR}/.app_init_flag" ]]; then
        LOG_I "No injected configuration file found, creating default config files..."
        
        openldap_generate_conf

        touch "${APP_CONF_DIR}/.app_init_flag"
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> "${APP_CONF_DIR}/.app_init_flag"
    else
        LOG_I "User injected custom configuration detected!"

		LOG_D "Update configure files from environment..."
		openldap_update_conf
    fi

    if [[ ! -f "${APP_DATA_DIR}/.data_init_flag" ]]; then
        LOG_I "Deploying ${APP_NAME} from scratch..."

        [[ ! -e ${APP_DATA_DIR}/DB_CONFIG ]] && cp ${APP_CONF_DIR}/DB_CONFIG.example ${APP_DATA_DIR}/DB_CONFIG

		# 启动后台服务
        openldap_start_server_bg
        
        openldap_root_credentials

        if is_boolean_yes "$LDAP_ENABLE_TLS"; then
            openldap_generate_lts_conf
        fi

        if is_boolean_yes "$LDAP_SKIP_DEFAULT_TREE"; then
            LOG_I "Skipping default schemas/tree structure"
        else
            # 使用相应的 schemas/tree 初始化 OpenLDAP
            openldap_add_modules
            openldap_add_schemas
            if ! is_dir_empty "$LDAP_CUSTOM_SCHEMA_DIR"; then
                openldap_add_custom_schema
            fi

            if ! is_dir_empty "$LDAP_CUSTOM_LDIF_DIR"; then
                openldap_add_custom_ldifs
            else
                openldap_create_tree
                openldap_create_users
            fi
        fi

        touch ${APP_DATA_DIR}/.data_init_flag
        echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> ${APP_DATA_DIR}/.data_init_flag
    else
        LOG_I "Deploying ${APP_NAME} with persisted data..."
    fi
}

# 用户自定义的前置初始化操作，依次执行目录 preinitdb.d 中的初始化脚本
# 执行完毕后，生成文件 ${APP_DATA_DIR}/.custom_preinit_flag
openldap_custom_preinit() {
    LOG_I "Check custom pre-init status of ${APP_NAME}..."

    # 检测用户配置文件目录是否存在 preinitdb.d 文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/preinitdb.d" ]; then
        # 检测数据存储目录是否存在已初始化标志文件；如果不存在，检索可执行脚本文件并进行初始化操作
        if [[ -n $(find "/srv/conf/${APP_NAME}/preinitdb.d/" -type f -regex ".*\.\(sh\)") ]] && \
            [[ ! -f "${APP_DATA_DIR}/.custom_preinit_flag" ]]; then
            LOG_I "Process custom pre-init scripts from /srv/conf/${APP_NAME}/preinitdb.d..."

            # 检索所有可执行脚本，排序后执行
            find "/srv/conf/${APP_NAME}/preinitdb.d/" -type f -regex ".*\.\(sh\)" | sort | process_init_files

            touch "${APP_DATA_DIR}/.custom_preinit_flag"
            echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> "${APP_DATA_DIR}/.custom_preinit_flag"
            LOG_I "Custom preinit for ${APP_NAME} complete."
        else
            LOG_I "Custom preinit for ${APP_NAME} already done before, skipping initialization."
        fi
    fi

    # 检测依赖的服务是否就绪
    #for i in ${SERVICE_PRECONDITION[@]}; do
    #    openldap_wait_service "${i}"
    #done
}

# 用户自定义的应用初始化操作，依次执行目录initdb.d中的初始化脚本
# 执行完毕后，生成文件 ${APP_DATA_DIR}/.custom_init_flag
openldap_custom_init() {
    LOG_I "Check custom initdb status of ${APP_NAME}..."

    # 检测用户配置文件目录是否存在 initdb.d 文件夹，如果存在，尝试执行目录中的初始化脚本
    if [ -d "/srv/conf/${APP_NAME}/initdb.d" ]; then
    	# 检测数据存储目录是否存在已初始化标志文件；如果不存在，检索可执行脚本文件并进行初始化操作
    	if [[ -n $(find "/srv/conf/${APP_NAME}/initdb.d/" -type f -regex ".*\.\(sh\|sql\|sql.gz\)") ]] && \
            [[ ! -f "${APP_DATA_DIR}/.custom_init_flag" ]]; then
            LOG_I "Process custom init scripts from /srv/conf/${APP_NAME}/initdb.d..."

            # 启动后台服务
            openldap_start_server_bg

            # 检索所有可执行脚本，排序后执行
    		find "/srv/conf/${APP_NAME}/initdb.d/" -type f -regex ".*\.\(sh\|sql\|sql.gz\)" | sort | while read -r f; do
                case "$f" in
                    *.sh)
                        if [[ -x "$f" ]]; then
                            LOG_D "Executing $f"; "$f"
                        else
                            LOG_D "Sourcing $f"; . "$f"
                        fi
                        ;;
                    *.ldif)    
                        LOG_D "Executing $f"; 
                        postgresql_execute "${PG_DATABASE}" "${PG_INITSCRIPTS_USERNAME}" "${PG_INITSCRIPTS_PASSWORD}" < "$f"
                        ;;
                    *)        
                        LOG_D "Ignoring $f" ;;
                esac
            done

            touch "${APP_DATA_DIR}/.custom_init_flag"
    		echo "$(date '+%Y-%m-%d %H:%M:%S') : Init success." >> "${APP_DATA_DIR}/.custom_init_flag"
    		LOG_I "Custom init for ${APP_NAME} complete."
    	else
    		LOG_I "Custom init for ${APP_NAME} already done before, skipping initialization."
    	fi
    fi

}

