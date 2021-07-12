# Ver: 1.8 by Endial Fang (endial@126.com)
#

# 可变参数 ========================================================================

# 设置当前应用名称及版本
ARG app_name=openldap
ARG app_version=2.4.59

# 设置默认仓库地址，默认为 阿里云 仓库
ARG registry_url="registry.cn-shenzhen.aliyuncs.com"

# 设置 apt-get 源：default / tencent / ustc / aliyun / huawei
ARG apt_source=aliyun

# 编译镜像时指定用于加速的本地服务器地址
ARG local_url=""


# 0. 预处理 ======================================================================
FROM ${registry_url}/colovu/dbuilder as builder

# 声明需要使用的全局可变参数
ARG app_name
ARG app_version
ARG registry_url
ARG apt_source
ARG local_url

# 选择软件包源(Optional)，以加速后续软件包安装
RUN select_source ${apt_source};

# 安装依赖的软件包及库(Optional)
RUN install_pkg groff groff-base libtool libltdl7 libltdl-dev libperl-dev libssl1.1 libssl-dev libcrypto++-dev libsasl2-dev

# 设置工作目录
WORKDIR /tmp

# 参考文档: 
#     编译: https://www.cnblogs.com/si-jie/p/8214206.html
#     seolim解决(groff): http://www.emreakkas.com/linux-tips/ubuntu-solve-bin-sh-soelim-not-found

ENV dbName=db \
    dbVersion=5.1.29

# 下载并解压软件包(BerkeleyDB 5.1.29)
RUN set -eux; \
	appName=${dbName}-${dbVersion}.tar.gz; \
	[ ! -z ${local_url} ] && localURL=${local_url}/berkeley; \
	appUrls="${localURL:-} \
		http://download.oracle.com/berkeley-db \
		"; \
	download_pkg unpack ${appName} "${appUrls}"; 

# 源码编译(BerkeleyDB)
RUN set -eux; \
	APP_SRC="/tmp/${dbName}-${dbVersion}"; \
	cd ${APP_SRC}/build_unix; \
	../dist/configure \
		--prefix=/usr/local/${dbName} \
		; \
	make -j "$(nproc)"; \
	make install; \
	echo "/usr/local/${dbName}/lib/" >> /etc/ld.so.conf; \
	ldconfig; \
	rm -rf ${APP_SRC};

# 下载并解压软件包(OpenLDAP 2.4.59)
RUN set -eux; \
	appName=${app_name}-${app_version}.tgz; \
	[ ! -z ${local_url} ] && localURL=${local_url}/${app_name}; \
	appUrls="${localURL:-} \
		https://www.openldap.org/software/download/OpenLDAP/openldap-release \
		"; \
	download_pkg unpack ${appName} "${appUrls}"; 

# 源码编译(OpenLDAP)
RUN set -eux; \
	APP_SRC="/tmp/${app_name}-${app_version}"; \
	cd ${APP_SRC}; \
	./configure \
		--prefix=/usr/local/${app_name} \
		CPPFLAGS="-I/usr/local/db/include -D_GNU_SOURCE" \
		LDFLAGS="-L/usr/local/db/lib" \
		--enable-modules \
		--enable-dynamic \
		--enable-backends=mod \
		--enable-overlays=mod \
		--enable-spasswd \
		--enable-crypt \
		--enable-sql=no \
		--enable-ndb=no \
		; \
	make depend; \
	make -j "$(nproc)"; \
	make install;

# 删除编译生成的多余文件
RUN set -eux; \
	find /usr/local -name '*.a' -delete; \
	rm -rf /usr/local/${app_name}/share; \
	rm -rf /usr/local/${app_name}/include; \
	rm -rf /usr/local/db/include; \
	rm -rf /usr/local/db/docs; 

# 检测并生成依赖文件记录
RUN set -eux; \
	find /usr/local/${app_name} -type f -executable -exec ldd '{}' ';' | \
		awk '/=>/ { print $(NF-1) }' | \
		sort -u | \
		xargs -r dpkg-query --search 2>/dev/null | \
		cut -d: -f1 | \
		sort -u >/usr/local/${app_name}/runDeps;


# 1. 生成镜像 =====================================================================
FROM ${registry_url}/colovu/debian:buster

# 声明需要使用的全局可变参数
ARG app_name
ARG app_version
ARG registry_url
ARG apt_source
ARG local_url

# 镜像所包含应用的基础信息，定义环境变量，供后续脚本使用
ENV APP_NAME=${app_name} \
	APP_EXEC=slapd \
	APP_VERSION=${app_version}

ENV	APP_HOME_DIR=/usr/local/${APP_NAME} \
	APP_DEF_DIR=/etc/${APP_NAME}

ENV PATH="${APP_HOME_DIR}/sbin:${APP_HOME_DIR}/bin:${APP_HOME_DIR}/libexec:${PATH}" \
	LD_LIBRARY_PATH="/usr/local/db/lib:${APP_HOME_DIR}/lib"

LABEL \
	"Version"="v${app_version}" \
	"Description"="Docker image for ${app_name}(v${app_version})." \
	"Dockerfile"="https://github.com/colovu/docker-${app_name}" \
	"Vendor"="Endial Fang (endial@126.com)"

# 从预处理过程中拷贝软件包(Optional)，可以使用阶段编号或阶段命名定义来源
COPY --from=0 /usr/local/db /usr/local/db
COPY --from=0 /usr/local/${APP_NAME} /usr/local/${APP_NAME}

# 拷贝应用使用的客制化脚本，并创建对应的用户及数据存储目录
COPY customer /
RUN set -eux; \
	prepare_env; \
	/bin/bash -c "ln -sf /usr/local/${APP_NAME}/etc/${APP_NAME} /etc/";

# 选择软件包源(Optional)，以加速后续软件包安装
RUN select_source ${apt_source}

# 安装依赖的软件包及库(Optional)
RUN install_pkg `cat /usr/local/${APP_NAME}/runDeps`; 
RUN install_pkg pwgen

# 执行预处理脚本，并验证安装的软件包
RUN set -eux; \
	override_file="/usr/local/overrides/overrides-${APP_VERSION}.sh"; \
	[ -e "${override_file}" ] && /bin/bash "${override_file}"; \
	${APP_EXEC} -V | :;

# 默认提供的数据卷
VOLUME ["/srv/conf", "/srv/data", "/srv/datalog", "/srv/cert", "/var/log"]

# 默认使用gosu切换为新建用户启动，必须保证端口在1024之上
EXPOSE 8389 8636

# 关闭基础镜像的健康检查
#HEALTHCHECK NONE

# 应用健康状态检查
HEALTHCHECK --interval=10s --timeout=10s --retries=3 \
	CMD netstat -ltun | grep 8389

# 使用 non-root 用户运行后续的命令
USER 1001

# 容器初始化命令
ENTRYPOINT ["/usr/local/bin/entry.sh"]

# 应用程序的启动命令，必须使用非守护进程方式运行
CMD ["/usr/local/bin/run.sh"]
