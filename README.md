# RPG Maker MZ + RPG Reactor + TypeScript 初始化模板

这是一个面向 **macOS Apple Silicon** 的 RPG Maker MZ 初始化模板。

目标是保留 RPG Maker MZ 的地图、数据库、事件与 Plugin Command 编辑体验，同时把运行时切换到 RPG Reactor，并使用现代 TypeScript + Vite 工作流开发第一方插件。

下面是原始 `0.98.7` 模板的验证记录；新增类型安装流程见下一节。

```text
GitHub fresh clone
→ ./scripts/bootstrap-mac.sh
→ MZ stock assets hydrate
→ RPG Reactor runtime hydrate
→ NW.js 0.117.0 ARM64
→ pnpm install
→ TypeScript typecheck
→ Vite build
→ doctor 20 PASS
→ Git working tree clean
→ RPG Maker MZ GUI Playtest
→ PixiJS 8 native ParticleContainer 正常运行
```

## 安装本地 RPGReactor 的 runtime 和类型

第一次使用包含自定义声明的本地源码时执行：

```bash
REACTOR_SOURCE="/Users/dingshinn/Desktop/RPGReactor" ./scripts/bootstrap-mac.sh
```

已有项目只更新引擎和类型，无需重新安装 NW.js 或资源：

```bash
REACTOR_SOURCE="/Users/dingshinn/Desktop/RPGReactor" ./scripts/setup-reactor.sh --install
pnpm --dir src typecheck
pnpm --dir src build
```

安装成功后，源码路径保存在 Git 忽略的 `.reactor-source`。后续直接运行
`./scripts/bootstrap-mac.sh` 或 `./scripts/setup-reactor.sh --install` 即可继续使用它。
其他机器首次运行需指定自己的源码路径。本地模式读取该源码的 runtime 版本，
不受下表远程下载版本约束；本次接入的是 `0.98.8 / 20260927.34`。

安装映射如下：

| RPGReactor 源码 | MZ 工程内的位置 |
|---|---|
| `runtime/reactor_*.js`、`runtime/libs/` | `js/reactor_*.js`、`js/libs/` |
| `types/*.d.ts`、`types/compat/` | `src/vendor/rpgreactor/types/` |
| `types/tools/typecheck.cjs` | `src/vendor/rpgreactor/types/tools/typecheck.cjs` |

源码需要包含本次为 `typecheck.cjs` 增加的 `--compiler-root` 参数支持。
安装只同步声明、兼容工具和许可证，不复制上游测试、示例或机器生成的 DOM 文件。
`src/vendor/rpgreactor/` 不进 Git，由安装脚本维护；自己的类型扩展放在 `src/types/`。
安装检查包含声明文件的 SHA-256，即使 runtime 版本未变，声明更新或丢失也会重新同步。

`pnpm --dir src typecheck` 先用项目安装的 TypeScript 7.0.2 生成 DOM 兼容声明，
再检查插件及 Vite 配置。游戏类型配置使用上游 WebGPU 适配和 `skipLibCheck: false`；
Vite 的 Node 环境由 `src/tsconfig.tools.json` 单独检查。
原来的 `src/types/mz.d.ts` 已由引擎声明替代，PIXI 全局和 NW.js 补充声明仍保留。
这些文件只参与开发检查，不会作为 JS 加载进游戏。

原来的远程快照没有你本地新增的 `types/`，因此尚不能支持带类型的全新安装。
若要让别人通过下载模式一键初始化，先将声明及工具发布到自己的 fork，
再更新 `scripts/versions.env` 的仓库、commit、版本和 revision，最后运行：

```bash
REACTOR_SOURCE=download ./scripts/bootstrap-mac.sh
```

缺少声明的源码会在修改游戏 runtime 之前报错。RPGReactor 编辑器菜单中的
`Install Reactor Runtime...` 是另一条安装路径，本次没有修改该菜单；此模板直接由
`scripts/setup-reactor.sh` 同步源码。

安装流程回归测试：`node --test scripts/tests/reactor-install.test.cjs`。

## 远程下载模式锁定的版本

| 组件 | 版本 |
|---|---|
| RPG Reactor | `0.98.7` |
| Reactor commit | `1a6501bc5dbe7c03befe56cd4ed5673b5ed060c0` |
| Reactor runtime revision | `20260920.24` |
| NW.js SDK | `0.117.0` |
| NW.js 架构 | `arm64` |
| Chromium | `154.0.8037.58` |
| PixiJS | `8.20.0` |
| Node.js（开发环境） | `>=22` |
| pnpm | `10.20.0` |
| TypeScript | `7.0.2` |
| Vite | `8.3.1` |

版本来源统一记录在：

```text
scripts/versions.env
```

## 当前做过的更新

### 1. MZ 继续作为日常编辑器

保留 RPG Maker MZ GUI，用于：

- 地图
- 数据库
- 事件
- Plugin Command
- 项目数据

日常不需要使用 RPG Reactor Editor。

### 2. 游戏运行时切换为 RPG Reactor

bootstrap 后会本地生成：

```text
js/reactor_*.js
js/libs/*
index.html
```

并建立：

```text
js/reactor_plugins.js -> plugins.js
```

因此 MZ Plugin Manager 继续维护 `js/plugins.js`，Reactor runtime 读取同一份插件清单。

### 3. MZ Playtest NW.js 升级为现代 ARM64

当前固定：

```text
NW.js 0.117.0
Chromium 154.0.8037.58
ARM64
```

已经验证：

```js
process.arch === "arm64"
```

在 Apple Silicon Mac 上不再依赖旧 x86_64 NW.js + Rosetta。

> 注意：NW.js 替换发生在 RPG Maker MZ 应用安装本身，会影响该 MZ 安装启动的 Playtest。Steam/MZ 更新可能覆盖它，届时重新运行 bootstrap 即可。

### 4. 第一方插件迁移到 TypeScript + Vite

现代工程位于：

```text
src/
```

MZ 根目录的 `package.json` 继续只负责 MZ/NW.js。

现代工具链独立拥有：

```text
src/package.json
src/pnpm-lock.yaml
src/tsconfig.json
src/vite.config.mts
```

因此 MZ/Reactor 自带的大量 `.js` 不进入 TypeScript 编译或类型检查。

### 5. PixiJS npm 包只作为开发期 SDK / typings

开发时使用：

```text
pixi.js@8.20.0
```

运行时仍使用 Reactor 已加载的：

```js
globalThis.PIXI
```

不会 bundle 第二份 PixiJS。

### 6. Vite 输出 classic MZ 插件

TypeScript：

```text
src/plugins/RR_Pixi8Particles.ts
```

构建为：

```text
js/plugins/RR_Pixi8Particles.js
```

输出是 classic IIFE，而不是 ESM，适配 Reactor/MZ 当前 script loader。

### 7. MZ Plugin metadata 独立维护

metadata 放在：

```text
src/plugins/RR_Pixi8Particles.meta.txt
```

Vite 构建时自动注入到最终 JS。

### 8. MZ stock 资源不进入公共 Git 仓库

模板不会提交 MZ 默认：

```text
audio/
img/
fonts/
effects/
icon/
css/
js/plugins/*.js
```

bootstrap 从本机合法安装的：

```text
RPGMZ.app/Contents/Resources/newdata
```

hydrate。

stock 文件的精确路径写入：

```text
.git/info/exclude
```

因此：

```text
MZ stock 文件                 → 本 clone 本地忽略
你自己新增的游戏资产           → Git 正常跟踪
```

### 9. 一键 bootstrap

已经实现：

```bash
./scripts/bootstrap-mac.sh
```

它会自动：

```text
0. Preflight
1. 检查/安装现代 NW.js
2. hydrate 固定版本 RPG Reactor
3. hydrate 本机 MZ stock assets
4. pnpm install --frozen-lockfile
5. TypeScript typecheck
6. Vite build
7. 完整 doctor
```

### 10. doctor

```bash
./scripts/doctor.sh
```

当前 fresh clone 验证结果：

```text
20 passed, 0 warnings, 0 failed
```

并且 bootstrap 结束后：

```bash
git status --short
```

保持 clean。

## 走完整套 SOP 后会得到什么

从 GitHub 上一个只有 source-of-truth 的模板仓库开始：

```text
GitHub Template
    ↓
clone
    ↓
./scripts/bootstrap-mac.sh
```

最终本地会成为：

```text
完整 RPG Maker MZ 工程
├── MZ stock assets
├── Reactor runtime
├── modern ARM64 NW.js Playtest host
├── TypeScript dependencies
├── 构建后的第一方 MZ plugins
└── 可直接 MZ GUI Playtest
```

同时 Git 仍然只追踪真正的 source：

```text
data/
src/
scripts/
game.rmmzproject
package.json
js/plugins.js
你自己新增的游戏资产
```

## 是否只能在当前这台 Mac 使用

不是绑定某一台具体 Mac。

当前实现绑定的是：

```text
macOS + Apple Silicon/arm64 + 可识别的 RPG Maker MZ 安装布局
```

另一台 Apple Silicon Mac，只要满足前置条件，原则上可以直接使用同一套流程。

如果 MZ 不在默认 Steam 路径：

```bash
MZ_APP="/path/to/RPGMZ.app" ./scripts/bootstrap-mac.sh
```

### 当前还未支持

当前脚本没有验证/适配：

```text
Intel Mac / x86_64
Windows
Linux
```

尤其 Intel Mac 当前不能直接使用，因为 NW.js pin 是：

```text
osx-arm64
```

## 前置条件

另一台 Apple Silicon Mac 至少需要：

1. macOS。
2. Apple Silicon（arm64）。
3. 已合法安装 RPG Maker MZ。
4. MZ 安装中存在：
   ```text
   RPGMZ.app/Contents/Resources/newdata
   RPGMZ.app/Contents/Resources/nwjs-mac
   ```
5. Git。
6. Node.js 22 或更高版本。
7. pnpm。
8. 可访问 GitHub 与 NW.js 下载站点。
9. 系统命令：
   ```text
   bash
   tar
   unzip
   ditto
   file
   curl
   ```
10. 可选：`aria2c`。如果存在，下载脚本优先使用，并使用多连接下载。

## 快速开始

建议先把本仓库设为 GitHub Template Repository。

创建一个新的游戏仓库后：

```bash
git clone <your-game-repo>
cd <your-game-repo>

./scripts/bootstrap-mac.sh
```

完成后：

```bash
pnpm --dir src dev
```

然后 RPG Maker MZ 打开：

```text
game.rmmzproject
```

正常开发：

```text
编辑地图 / 数据库 / 事件
→ 保存
→ ▶ Playtest
```

## 日常开发

Terminal：

```bash
pnpm --dir src dev
```

IDE：

```text
修改 src/**/*.ts
→ 保存
→ Vite 自动 build
→ js/plugins/*.js
```

MZ：

```text
▶ Playtest
```

Source map 已实际验证，DevTools 日志可以定位回 `.ts` 源文件。

## 项目结构

```text
.
├── data/
├── game.rmmzproject
├── package.json
├── js/
│   ├── plugins.js
│   ├── plugins/
│   ├── libs/                 # local hydrate，不进 Git
│   ├── reactor_*.js          # local hydrate，不进 Git
│   └── reactor_plugins.js    # -> plugins.js
├── src/
│   ├── package.json
│   ├── pnpm-lock.yaml
│   ├── tsconfig.json
│   ├── vite.config.mts
│   ├── plugins/
│   ├── types/                # 项目自身的补充声明
│   ├── vendor/rpgreactor/    # 安装的引擎类型，不进 Git
│   └── tsconfig.tools.json  # Vite / Node 类型环境
└── scripts/
    ├── bootstrap-mac.sh
    ├── doctor.sh
    ├── setup-mz-assets-mac.sh
    ├── setup-nwjs-mac.sh
    ├── setup-reactor.sh
    └── versions.env
```

## 脚本

一键初始化：

```bash
./scripts/bootstrap-mac.sh
```

跳过 NW.js：

```bash
./scripts/bootstrap-mac.sh --skip-nwjs
```

环境检查：

```bash
./scripts/doctor.sh
```

Reactor：

```bash
./scripts/setup-reactor.sh --check
./scripts/setup-reactor.sh --install
./scripts/setup-reactor.sh --install --force
```

NW.js：

```bash
./scripts/setup-nwjs-mac.sh --check
./scripts/setup-nwjs-mac.sh --install
./scripts/setup-nwjs-mac.sh --install --force
```

MZ stock：

```bash
./scripts/setup-mz-assets-mac.sh --check
./scripts/setup-mz-assets-mac.sh --install
```

## Git 策略

Git source-of-truth：

```text
data/
src/
scripts/
game.rmmzproject
package.json
js/plugins.js
```

本地生成 / hydrate：

```text
index.html
js/libs/
js/reactor_*.js
js/reactor_plugins.js
js/plugins/RR_*.js
src/node_modules/
save/
rpgmaker-runtime-backup*.zip
```

要主动追踪某个修改过的 stock 文件：

```bash
git add -f img/system/Window.png
```

## 当前 smoke test

模板目前包含 `RR_Pixi8Particles`，已经验证：

```text
MZ Plugin Command
→ TypeScript/Vite
→ Reactor 0.98.7
→ PixiJS 8.20.0
→ PIXI.Particle
→ native ParticleContainer
```

当前实际 Playtest 已验证：

```text
PIXI.VERSION = 8.20.0
RPG_REACTOR_RUNTIME_REVISION = 20260920.24
process.arch = arm64
NW.js = 0.117.0
```

## 已知限制

1. 当前只支持 macOS。
2. 当前 NW.js 固定 ARM64，因此 Intel Mac 暂不支持。
3. Reactor 首次下载当前获取完整 GitHub source tarball，约数百 MB；实际只需要 `runtime/`，后续可优化。
4. MZ 更新可能恢复官方 NW.js。
5. 脚本依赖当前 MZ 的 `Contents/Resources/newdata` 布局。
6. Reactor 更新较快，因此模板使用固定版本，不自动追 latest。
7. 当前 Vite 仍是单插件 entry；开始正式框架开发后建议改成多插件自动发现。

## 版本升级原则

不要直接改成 latest。

标准流程：

```text
修改版本 pin
→ 本机安装/构建
→ doctor
→ MZ GUI Playtest
→ push
→ fresh GitHub clone
→ ./scripts/bootstrap-mac.sh
→ git status clean
→ 再确认升级完成
```

详细操作见 `SOP.zh-CN.md`。
