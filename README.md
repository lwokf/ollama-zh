# Ollama 汉化补丁 (Ollama 中文版)

Ollama 桌面端官方只有英文界面,且没有 i18n 支持(UI 通过 `go:embed` 编译进二进制)。
本仓库提供**可复现的汉化补丁 + 自动构建流水线**,每个官方版本自动产出对应的"汉化补丁"单文件包。

- 官方更新照常保留,更新后重新运行一次补丁即可恢复中文
- 只替换桌面端 `ollama app.exe`(UI 壳),服务端 `ollama.exe` 保持官方原版(推理引擎/模型不受影响)
- 汉化不修改版本号,`ollama --version` 与官方更新检测均正常

## 快速使用

1. 到本仓库 **Releases** 下载最新 `ollama-zh-vX.Y.Z-win64.zip`
2. 退出正在运行的 Ollama(托盘图标右键 → 退出 Ollama)
3. 解压 zip,右键"以管理员身份运行 PowerShell",在解压目录执行:

   ```powershell
   .\apply-patch.ps1
   ```

4. 重新启动 Ollama → 界面为中文

### 解压位置:任意目录都可以

补丁包可以解压到**任意目录**(桌面、下载、D 盘任意文件夹都行),**不需要**放进 Ollama 安装目录。
脚本会自动查找 Ollama 安装位置(依次检测 `D:\ollama`、`%LOCALAPPDATA%\Programs\Ollama`、`C:\Program Files\Ollama`,也可以手动指定):

```powershell
.\apply-patch.ps1 -InstallDir "D:\你的安装路径"
```

唯一要求:**`apply-patch.ps1` 和 `ollama app.exe` 必须保持在同一文件夹内**(脚本从自身所在目录查找汉化版 exe)。

### 官方更新之后

官方更新会把 exe 覆盖回英文。**重新运行一次 `apply-patch.ps1` 即可恢复中文**(自动备份官方 exe)。

### 还原官方原版

```powershell
.\apply-patch.ps1 -Restore
```

## 目录结构

```
translations/zh-CN.json    # 中英对照翻译词典(改这里加翻译)
translations/zh-CN.patch   # 由词典生成的可复现汉化补丁
tools/extract_strings.py   # 提取源码中的英文 UI 字符串
tools/translate.mjs        # 根据词典生成/应用补丁
scripts/apply-patch.ps1    # 用户侧补丁应用脚本
.github/workflows/build-zh.yml  # 自动构建流水线
```

## 流水线如何工作

`.github/workflows/build-zh.yml`(每日定时 + 手动触发):

```
检测上游新 Release → 克隆对应 tag → 应用 zh-CN.patch
→ npm run build(前端) → go build(桌面端,MinGW CGO)
→ 打包 zip → 发布 Release(zh-vX.Y.Z)
```

每个官方版本对应一个 `zh-vX.Y.Z` Release 标签,已构建的版本不会重复构建。

## 自己构建 / 贡献翻译

```bash
# 1. 准备:Go 1.22+、gcc(g++/MinGW)、Node 18+
# 2. 克隆上游并应用补丁
git clone --depth 1 --branch v0.32.5 https://github.com/ollama/ollama.git upstream
git -C upstream apply translations/zh-CN.patch
# 3. 构建前端
cd upstream/app/ui/app && npm install && npm run build && cd ../..
# 4. 编译桌面端(Windows)
CGO_ENABLED=1 go build -trimpath \
  -ldflags "-s -w -H windowsgui -X=github.com/ollama/ollama/app/version.Version=v0.32.5" \
  -o "ollama app.exe" ./app/cmd/app/
```

修改翻译:`translations/zh-CN.json` 增删条目后,重新生成补丁:

```bash
node tools/translate.mjs <上游源码目录> <输出目录>
# 在输出目录内用 git diff 生成新的 zh-CN.patch
```

## 注意事项

- 补丁与上游版本一一对应;请使用与已安装版本匹配的补丁
- 汉化范围:桌面端 UI(聊天/模型/设置/托盘菜单/文件对话框)。日志与模型工具描述保持英文,避免影响模型行为
- 上游快速迭代,若补丁应用失败(上游改了代码),请提 Issue 或更新词典后重新生成
