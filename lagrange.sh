#!/bin/bash
set -e

echo -e "\e[96m 执行之前请确保有docker环境，并且处于开启状态 \e[0m"
echo -e "\e[96m   第二次执行前请确保没有打包缓存，执行 docker system prune 将你关闭的容器一并删除 \e[0m"

# 提示用户选择
echo -e "\e[96m 是否执行脚本？ (y/n) \e[0m"
read -n 1 choice

# 判断用户选择
if [[ $choice =~ ^[yY]$ ]]; then
  echo "将继续执行........."
  # 执行脚本
else
  echo "退出 exit....."
  exit 0
fi

# 定义默认参数
image_name="lagrangedev/lagrange.onebot"
image_version="edge"
data_dir="/home/lagrangedev/data"
config_file="/home/lagrangedev/data/appsettings.json"
lagrange_docker_name="lagrangedev-device-service"

# 解析脚本参数
while getopts ":i:v:d:c:" opt; do
  case $opt in
    i)
      image_name=$OPTARG
      ;;
    v)
      image_version=$OPTARG
      ;;
    d)
      data_dir=$OPTARG
      ;;
    c)
      config_file=$OPTARG
      ;;
  esac
done



# 清理缓存
# echo "正在清理 Docker 缓存..."
# docker system prune
# echo "缓存清理完成。"
# 拉取代码
echo "正在拉取代码..."
git clone https://github.com/LagrangeDev/Lagrange.Core.git
cd Lagrange.Core
echo "代码拉取完成。"

echo "正在生成 Dockerfile 文件..."

cat > Dockerfile <<EOL

FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine3.18 AS build-env
WORKDIR /App

COPY . ./
RUN dotnet publish Lagrange.OneBot/Lagrange.OneBot.csproj \
        -c Release \
        -o out \
        --no-self-contained \
        -p:PublishSingleFile=true \
        -p:IncludeContentInSingleFile=true \
            --framework net8.0

FROM mcr.microsoft.com/dotnet/runtime:8.0-alpine3.18
WORKDIR /app
COPY --from=build-env /App/out .
COPY Lagrange.OneBot/Resources/appsettings.onebot.json ./appsettings.json
ENTRYPOINT ["./Lagrange.OneBot"]
EOL
echo "Dockerfile 文件生成完成。"
echo "正在构建镜像..."
# 构建镜像
docker build -t ${image_name}:${image_version} .
echo "镜像构建完成。"

echo "正在创建目录..."
# 创建目录
mkdir -p ${data_dir}
echo "目录创建完成。"
# 配置参数


echo "正在配置参数..."
cat > ${config_file} <<EOL
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.Hosting.Lifetime": "Information"
    }
  },
  "ConfigPath": {
    "Keystore": "./data/keystore.json",
    "DeviceInfo": "./data/device.json",
    "Database": "./data/Lagrange.db"
  },
  "SignServerUrl": "https://sign.libfekit.so/api/sign",
  "Account": {
    "Uin": 0,
    "Password": "",
    "Protocol": "Linux",
    "AutoReconnect": true,
    "GetOptimumServer": true
  },
  "Implementations": [
    {
      "Type": "ForwardWebSocket",
      "Host": "0.0.0.0",
      "Port": 8081,
      "HeartBeatInterval": 5000,
      "AccessToken": ""
    }
  ]
}
EOL
echo "参数配置完成。"
echo "尝试运行容器"
# 运行容器
docker run -d --name ${lagrange_docker_name}\
  --restart=always \
  --dns 119.29.29.29 \
  -p 8081:8081 \
  -v ${data_dir}:/app/data \
  -v ${config_file}:/app/appsettings.json \
  ${image_name}:${image_version}

docker ps -a

docker logs -f ${lagrange_docker_name}