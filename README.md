## 目录说明

| 目录 | 说明 | 构建命令 |
| --- | --- | --- |
| `cli/` | 命令行工具，用于部署和管理 Laf 应用 |  |
| `packages/` | 核心 SDK 包集合 |  |
| `runtimes/` | 云函数运行时环境，支持多种语言 | build-image.sh |
| `server/` | 后端服务，基于 NestJS 框架 |  |
| `web/` | 前端管理控制台，基于 React |  |
| `build/` | laf镜像构建文件 | `sealos build -t lafyun/laf:latest -f Kubefile .`
| `docs/` | 项目文档 |  |
