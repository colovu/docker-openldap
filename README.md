# OpenLDAP

针对 [OpenLDAP](https://www.openldap.org) 应用的 Docker 镜像，用于提供 OpenLDAP 服务。容器详细使用说明可参考仓库：[Gitee](https://www.gitee.com/endial/studylife.git) 或 [Github](https://www.github.com/endial/studylife.git)中`服务器运维`相应文档。

使用说明可参照：[官方说明](https://www.openldap.org/doc)

<img src="img/OpenLDAP-logo.gif" alt="OpenLDAP-logo" />

**版本信息：**

- 2.4、latest

**镜像信息：**

* 镜像地址：
  - Aliyun仓库：registry.cn-shenzhen.aliyuncs.com/colovu/openldap
  - DockerHub：colovu/openldap
  * 依赖镜像：debian:buster-slim

> 后续相关命令行默认使用`[Docker Hub](https://hub.docker.com)`镜像服务器做说明



## TL;DR

Docker 快速启动命令：

```shell
# 从 Docker Hub 服务器下载镜像并启动
$ docker run -d docker.io/colovu/openldap
```



Docker-Compose 快速启动命令：

```shell
# 从 Gitee 下载 Compose 文件
$ curl -sSL -o https://gitee.com/colovu/docker-openldap/raw/master/docker-compose.yml

# 从 Github 下载 Compose 文件
$ curl -sSL -o https://raw.githubusercontent.com/colovu/docker-openldap/master/docker-compose.yml

# 创建并启动容器
$ docker-compose up -d
```



---



## 默认对外声明

### 端口

- 8389：普通 LDAP 通讯端口
- 8639：TLS 加密 LDAP 通讯端口



### 数据卷

镜像默认提供以下数据卷定义，默认数据分别存储在自动生成的应用名对应`openldap`子目录中：

```shell
/var/datalog        # 数据操作日志文件
/srv/conf           # 配置文件
/srv/data           # 数据文件，主要存放应用数据
/srv/cert           # 证书文件存放目录

/var/log            # 日志输出
/var/run            # 系统运行时文件，如 PID 文件
```

如果需要持久化存储相应数据，需要**在宿主机建立本地目录**，并在使用镜像初始化容器时进行映射。宿主机相关的目录中如果不存在对应应用`openldap`的子目录或相应数据文件，则容器会在初始化时创建相应目录及文件。



## 使用镜像

以下使用镜像的样例中,我们使用 MariaDB Galera 实例连接 OpanLDAP 并进行用户认证.

### 定义网络

定义一个私有的网络`my-network`,以方便后续应用容器的连接:

```shell
$ docker network create my-network --driver bridge
```

### 启动 OpenLDAP 容器

使用之前定义的`my-network`网络初始化 OpenLDAP 容器:

```shell
$ docker run --detach --rm --name openldap \
  --network my-network \
  --env LDAP_BIND_UID=bind \
  --env LDAP_BIND_PASSWORD=bindpassword \
  --env LDAP_USERS=customuser \
  --env LDAP_PASSWORDS=custompassword \
  colovu/openldap:latest
```

### 启动 MariaDB Galera 容器

使用之前定义的`my-network`网络初始化 MariaDB Galera 容器:

```shell
$ docker run --detach --rm --name mariadb-galera \
    --network my-network \
    --env MARIADB_ROOT_PASSWORD=root-password \
    --env MARIADB_GALERA_MARIABACKUP_PASSWORD=backup-password \
    --env MARIADB_USER=customuser \
    --env MARIADB_DATABASE=customdatabase \
    --env MARIADB_ENABLE_LDAP=yes \
    --env LDAP_URI=ldap://openldap:8389 \
    --env LDAP_BASE=dc=example,dc=org \
    --env LDAP_BIND_DN=uid=bind,ou=Manager,dc=example,dc=org \
    --env LDAP_BIND_PASSWORD=bindpassword \
    bitnami/mariadb-galera:latest
```

### 启动 MariaDB client 容器验证

创建一个新的 MariaDB client 容器,进行验证客户端是否可以进行认证:

```shell
$ docker run -it --rm --name mariadb-client \
    --network my-network \
    bitnami/mariadb-galera:latest mysql -h mariadb-galera -u customuser -D customdatabase -pcustompassword
```


## 容器配置

在初始化 `OpenLDAP` 容器时，如果没有预置配置文件，可以在命令行中设置相应环境变量对默认参数进行修改。类似命令如下（配置环境变量`APP_ENV_KEY_NAME`的值为`key_value`）：

```shell
$ docker run -d -e "APP_ENV_KEY_NAME=key_value" colovu/openldap
```



### 常规配置参数

常规配置参数用来配置容器基本属性，一般情况下需要设置，主要包括：

- `LDAP_ROOT`：默认值：**dc=example,dc=org**。设置数据库根 DN
- `LDAP_ORGNIZATION_NAME`：默认值：**Colovu Lab**。设置数据库所属组织名
- `LDAP_ROOT_USERNAME`：默认值：**root**。设置 RootDN 用户名
- `LDAP_ROOT_PASSWORD`：默认值：**rootpassword**。设置 RootDN 用户密码
- `LDAP_BIND_UID`：默认值：**bind**。设置 Binder 用户 UID
- `LDAP_BIND_PASSWORD`：默认值：**bindpassword**。设置 Binder 用户密码
- `LDAP_ADMIN_UID`：默认值：**admin**。设置 Admin 用户 UID
- `LDAP_ADMIN_PASSWORD`：默认值：**adminpassword**。设置 Admin 用户密码
- `LDAP_ADMIN_MAIL`：默认值：**admin@example.com**。设置 Admin 用户邮箱



### 常规可选参数

如果没有必要，可选配置参数可以不用定义，直接使用对应的默认值，主要包括：

- `ENV_DEBUG`：默认值：**false**。设置是否输出容器调试信息。可选值：no、true、yes
- `LDAP_BIND_GIVEN_NAME`：默认值：**false**。设置 Binder 用户名字
- `LDAP_BIND_SURNAME`：默认值：**false**。设置 Binder 用户姓氏
- `LDAP_ADMIN_GIVEN_NAME`：默认值：**false**。设置 Admin 用户名字
- `LDAP_ADMIN_SURNAME`：默认值：**false**。设置 Admin 用户姓氏
- `LDAP_PORT_NUMBER`：默认值：**8389**。非加密方式通讯端口
- `LDAP_LDAPS_PORT_NUMBER`：默认值：**8636**。TLS 加密方式通讯端口
- `LDAP_EXTRA_SCHEMAS`：默认值：**cosine,inetorgperson,nis**。设置加载的 Schema 文件
- `LDAP_EXTRA_MODULES`：默认值：**accesslog**。设置加载的动态库文件(back_hdb / back_monitor / refint / memberof 默认强制加载)
- `LDAP_CUSTOM_LDIF_DIR`：默认值：**initdb.d/ldifs**。设置用户自定义 LDIF 文件相对路径
- `LDAP_CUSTOM_SCHEMA_DIR`：默认值：**false**。设置用户自定义 Schema 文件相对路径
- `LDAP_ULIMIT_NOFILES`：默认值：**1024**。设置默认的系统最大打开文件句柄数,用于节省内存
- `LDAP_SKIP_DEFAULT_TREE`：默认值：**no**。设置是否初始化默认DN信息。可选值：no、yes
- `LDAP_USERS`：默认值：**user01,user02**。初始化时创建默认用户列表
- `LDAP_PASSWORDS`：默认值：**password1,password2**。初始化时创建默认用户对应的密码
- `LDAP_USER_OU`：默认值：**users**。初始化时创建默认用户所属 OU
- `LDAP_USER_GROUP`：默认值：**readers**。初始化时创建默认用户所属组



### 集群配置参数

配置服务为集群工作模式时，通过以下参数进行配置：

- 



### TLS配置参数

配置服务使用 TLS 加密时，通过以下参数进行配置：

- `LDAP_ENABLE_TLS`：默认值：**no**。设置是使用TLS加密。可选值：no、yes
- `LDAP_TLS_CERT_FILE`：默认值：**无**。设置 CERT 文件路径
- `LDAP_TLS_KEY_FILE`：默认值：**无**。设置 KEY 文件路径
- `LDAP_TLS_CA_FILE`：默认值：**无**。设置 CA 文件路径
- `LDAP_TLS_DH_PARAMS_FILE`：默认值：**无**。设置 DH 参数文件路径



## 安全

### 容器安全

本容器默认使用`non-root`运行应用，以加强容器的安全性。在使用`non-root`用户运行容器时，相关的资源访问会受限；应用仅能操作镜像创建时指定的路径及数据。使用`non-root`方式的容器，更适合在生产环境中使用。

如果需要赋予容器内应用访问外部设备的权限，可以使用以下两种方式：

- 启动参数增加`--privileged=true`选项
- 针对特定权限需要使用`--cap-add`单独增加特定赋权，如：ALL、NET_ADMIN、NET_RAW

如果需要切换为`root`方式运行应用，可以在启动命令中增加`-u root`以指定运行的用户。



## 注意事项

- 容器中应用的启动参数不能配置为后台运行，如果应用使用后台方式运行，则容器的启动命令会在运行后自动退出，从而导致容器退出



## 更新记录

- 2021/7/1 (2.4): 初始版本,基于 OpenLDAP 2.4.59



----

本文原始来源 [Endial Fang](https://github.com/colovu) @ [Github.com](https://github.com)

