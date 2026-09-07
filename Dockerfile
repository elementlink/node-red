# Stage 1: Build Stage
FROM node:22-alpine AS builder

# 设置工作目录
WORKDIR /usr/src/app

# 安装构建依赖（如需原生编译模块，可加上 python3, make, g++ 等）
# RUN apk add --no-cache python3 make g++

# 复制依赖定义文件
COPY package.json package-lock.json ./

RUN npm config set registry https://registry.npmmirror.com
# 安装所有依赖（包含 devDependencies 以用于构建）
RUN npm ci

# 复制项目所有源代码
COPY . .

# 运行构建脚本（会调用 scripts/build，执行 concat, sass, minify 等）
RUN npm run build

# 移除 devDependencies，减小最终镜像体积
RUN npm prune --omit=dev

# Stage 2: Production Stage
FROM node:22-alpine

# 安装常用工具（可选，如 tzdata 用于设置时区）
RUN apk update && \
    apk add --no-cache tzdata git && \
    # 清理 apk 缓存，进一步减小体积
    rm -rf /var/cache/apk/* && \
    rm -rf /var/lib/apt/lists/* 

# 创建 Node-RED 用户和用户组，并设置工作目录
WORKDIR /usr/src/node-red

# 从 builder 阶段拷贝编译好的代码和生产环境依赖
COPY --from=builder /usr/src/app /usr/src/node-red

# 设置环境变量
ENV NODE_ENV=production
ENV PORT=8080

# 暴露默认端口
EXPOSE 8080

RUN git config --global user.name "omviewer" && \
    git config --global user.email "omviewer@oldmutual.com"

# 切换至非 root 用户，增强安全性
USER node

# 启动 Node-RED，并显式指定项目内 settings.js
CMD ["node", "packages/node_modules/node-red/red.js", "--settings", "/usr/src/node-red/packages/node_modules/node-red/settings.js"]
