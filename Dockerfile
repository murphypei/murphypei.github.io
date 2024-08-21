# 使用 Ubuntu 18.04 作为基础镜像
FROM ubuntu:18.04

# 设置环境变量，防止交互提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新包列表并安装必要的工具
RUN apt-get update && \
    apt-get install -y curl gnupg2 ca-certificates lsb-release git

# 添加 NodeSource 的官方 PPA，并安装 Node.js 和 npm
WORKDIR /tmp
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - && apt-get install -y nodejs

COPY ./package.json /app/
COPY ./package-lock.json /app/
COPY ./_config.yml /app/
COPY ./scaffolds /app/
COPY ./source /app/
COPY ./themes /app/

WORKDIR /app
RUN npm install -g hexo-cli@3.1.0
# RUN npm install .
# RUN cp ./node_modules/live2d-widget-model-haru/package.json ./node_modules/live2d-widget-model-haru/01
# RUN cp ./node_modules/live2d-widget-model-haru/package.json ./node_modules/live2d-widget-model-haru/02

EXPOSE 4000

CMD ["/bin/bash"]
