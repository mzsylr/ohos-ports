# better-sqlite3 13.0.3：Electron-OH 37.2.0

在已有鸿蒙 Node port 上，增加显式启用的 Electron-OH arm64 原生文件。
沿用现有 0001/0002 补丁，不新增 C++/JS 逻辑修改；默认加载器、Node build.sh
和 Node 二进制保持不变。应用使用上游已有的 nativeBinding 参数。

## 支持范围与版本

已验证组合：OpenHarmony arm64、Electron-OH 37.2.0、内置 Node 22.17.0、N-API 10。
独立 Node 回归使用鸿蒙 Node 24.13.0。版本号相同的运行时也须校验实际文件哈希。

上游源码版本仍为 13.0.3；候选 npm 包使用下一补丁版本的 SemVer 预发布号
`13.0.4-electron-oh.0`，独立 dist-tag 为 `electron-oh`。这样不会使用低于已发布
13.0.3 的 `13.0.3-...` 预发布号；也不修改现有 Node 的 latest。
预发布版本标识的是分发包变更，不表示源码已升级至上游 13.0.4。
正式稳定版本和命名由维护者统一安排；当前不发布。

## 构建依赖来源

- Electron-OH 官方发行物：
  https://gitcode.com/CPF-Electron/Electron/releases/download/v37.2.0/v37.2.0-openharmony-arm64.zip
- shim：同一发行 ZIP 内的 `docs/electron-napi-library.zip`，使用其 `lib/libshim.a`。
- Node-API 头文件：Node.js 官方仓库固定 tag `v22.17.0/src/` 的四份公开 C API 头文件。
- node-addon-api：npm `node-addon-api@8.9.2`。
- OHOS NDK：从 DevEco Studio SDK Manager 安装。当前实测 Native SDK API 22 / 6.0.2.130。

发行 ZIP、shim ZIP、shim 库、libelectron.so、addon 源码和头文件的 SHA-256
分别保存在两个 lock 文件中。NDK 元数据和编译器版本写入生成的 manifest。
2026-10-21 官方 ZIP 地址匿名请求返回 HTTP 401；这不是公开可无认证下载的承诺。
可登录上游获取原 ZIP，再导入缓存；无需把 libshim.a 上传到本仓库：

```sh
python3 tools/prepare-electron-oh-deps.py \
  --archive /path/to/v37.2.0-openharmony-arm64.zip \
  --output /path/to/new-cache
```

脚本校验发行物、内嵌 shim 和最终运行时哈希，拒绝不安全解压路径；输出 profile.json
记录后续使用的 shim 根目录和运行时路径。不提供 --archive 时尝试官方地址，失败会
明确报错，不回退到未经验证的镜像。也可自行解压同一发行物并直接传入构建路径。
完整官方 ZIP 的导入在本次机器上未重跑，原始 ZIP 当前不在本机缓存；实际构建使用
已经解压且通过 lock 校验的 shim/libelectron.so。

## 构建与打包

需要 Bash、Python >= 3.11、patch、Node/npm、OHOS NDK。
先运行原 Node build.sh，或解压已经发布的 @ohos-ports/better-sqlite3@13.0.3 tarball，
得到含 SQLite amalgamation、defines.gypi 和 Node 预编译文件的基线包。

```sh
cd /path/to/prepared-node-package
npm install --ignore-scripts --omit=dev --no-save --package-lock=false node-addon-api@8.9.2

/path/to/port/build-electron-oh.sh \
  --source /path/to/prepared-node-package \
  --output /path/to/new-candidate-directory \
  --ndk /path/to/openharmony/native \
  --shim /path/to/electron-napi-library \
  --runtime-library /path/to/libelectron.so \
  --allow-unsigned

cd /path/to/new-candidate-directory
npm pack --ignore-scripts --pack-destination /path/to/artifacts
```

--allow-unsigned 仅生成本地 HAP 测试产物。若使用单文件自签名工具，将它替换为
`--sign-tool /path/to/binary-sign-tool`。strip 必须在签名前完成。
编译使用上游生成的 SQLite defines，链接 shim、静态 libc++；检查 AArch64、
注册入口、未解析 N-API/libuv 符号及 DT_NEEDED（当前仅 libc.so）。
原输入包不被修改，输出目录必须不存在。

```text
prebuilds/openharmony-arm64.node        原 Node 文件，逐字节保留
prebuilds/electron-oh/37.2.0/openharmony-arm64/
  better_sqlite3.node                  专用 Electron-OH 文件
  manifest.json                       输入、哈希、编译参数、签名状态
  THIRD_PARTY_NOTICES.txt              许可来源说明，尚需补齐完整 notices
```

当前 notice 文件明确属于待补齐状态。不能把插件内的许可证概述当作精确 shim
发行物的授权证明；正式二进制再分发前须收齐 shim、Node/Node-API、node-addon-api、
NDK 静态 libc++/LLVM 对应 LICENSE/NOTICE。源码 PR 和不发布的验证构建可先审阅。
manifest 的运行状态是构建时状态；运行后以外部、绑定制品哈希的报告附证，
不篡改已经测试过的 tarball 来追认通过。

## HAP 应用接入

安装候选 tgz，不执行 electron-rebuild。将 Electron 专用 .node 复制到
`electron/libs/arm64-v8a/better_sqlite3.node`，JS 包和 manifest 放在应用 node_modules。
shim 已静态链接，不需在 HAP 中另外部署 libshim.a，也不向库 npm 包混入整个 Electron。

根 build-profile.json5 对应 product 的 buildOption 中设置：

```json
{"nativeLib":{"collectAllLibs":true,"debugSymbol":{"strip":false}}}
```

关闭二次 strip，保持预编译文件哈希和签名。使用应用签名流程完成 HAP 原生代码签名。
本轮 demo 使用 SDK hap-sign-tool 的 signCode=1，验签、安装及功能验证均执行；
这不等于 npm 中 ELF 已完成 standalone self-sign。

Electron 主进程 app.whenReady() 后使用：

```js
const { app } = require('electron');
const path = require('node:path');
const Database = require('@ohos-ports/better-sqlite3');
app.whenReady().then(() => {
  if (process.platform !== 'openharmony' || process.arch !== 'arm64' ||
      process.versions.electron !== '37.2.0' || process.versions.node !== '22.17.0') {
    throw new Error('Unsupported Electron-OH runtime');
  }
  const db = new Database(path.join(app.getPath('userData'), 'app.db'), {
    nativeBinding: '/data/storage/el1/bundle/libs/arm64/better_sqlite3.node',
  });
  app.on('before-quit', () => db.close());
});
```

上述路径是已验证模板的实际安装路径；变更 HAP 模块布局后应重新确认。
数据库由主进程管理，renderer 通过应用 IPC 访问。普通 Node 仍直接 new Database(file)，
不传 nativeBinding，继续使用原 Node 预编译文件。
精简示例见 examples/electron-oh/main.cjs。

## 验证与 CI

```sh
python3 tests/verify-package.py baseline.tgz candidate.tgz
python3 tests/test-package-contract.py baseline.tgz candidate.tgz
# 在鸿蒙独立 Node 中：
node tests/node-smoke.cjs /path/to/installed/package
# Electron 主进程 ready 后调用 tests/electron-oh-smoke.cjs 导出函数。
```

CI 分为独立的宿主静态检查，以及手动触发的受信任 self-hosted Electron 构建。
后者要求 runner 标签 electron-oh、环境中提供 OHOS_NDK、ELECTRON_OH_SHIM、
ELECTRON_OH_RUNTIME_LIBRARY；每次仍校验哈希。当前官方下载需认证且 NDK 需安装，
所以不假定公共 Ubuntu runner 可匿名取得全部依赖。手动任务上传候选 tgz 和比较报告，
不调用 npm publish，不把 ELF 检查冒充真机测试。不要将未审阅 PR 送入特权 runner。
GitCode 目录存放的是面向 ohos-ports GitHub 仓库的 workflow 文件；需移入其 .github/workflows
并配置 runner 后才会执行，当前没有声称远端 CI 已跑通。

## 发布隔离

原 publish.sh 保留 Node latest 自动发布，不再使用默认关闭开关；增加已发布版本
跳过检查，防止仅更新 Electron 文件时重复发布 13.0.3。仅明确 E404 才继续原发布命令；
认证、网络和异常响应会失败退出，拒绝把 Electron 预发布包送入该入口。新增 CI 无 npm token、
无发布步骤。Electron 预发布只在完成完整 notices、最终签名及双宿主证据审阅后，
由维护者单独执行 npm publish --tag electron-oh；不使用 --tag latest。
提交源码、lock、文档和测试，不提交开发缓存、tgz、HAP、签名密钥或整个 Electron 发行物。
