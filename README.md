# Word Match Game 单词匹配游戏

一个现代化的单词匹配游戏项目，包含Web版本和Flutter移动端版本，帮助用户通过互动配对练习提高英语词汇量。

## 项目概述

本项目包含两个版本：
- **Web版本**：基于Next.js 15的现代化Web应用
- **Flutter版本**：跨平台移动应用（开发中）

## 🌟 功能特性

### Web版本功能
- 🎮 **互动式单词匹配游戏** - 点击卡片进行英中文配对
- 📚 **丰富的内置单词库** - 包含多个难度级别的单词列表
  - Word A/AA/B/C 系列（基础到进阶）
  - Fry Word Lists（常用词汇）
- 📤 **自定义单词导入** - 支持JSON和Excel格式文件导入
- ⏱️ **游戏计时系统** - 实时显示游戏用时
- 🎵 **音效反馈** - 匹配成功时播放提示音
- 🔊 **语音朗读** - 英文单词TTS朗读功能
- 📱 **响应式设计** - 完美适配桌面端和移动端
- 🎨 **现代化UI** - 使用shadcn/ui组件库，界面美观流畅
- ⚙️ **灵活配置** - 可调整配对数量（5-50对）
- 🎯 **游戏状态管理** - 完整的游戏流程控制

### 技术亮点
- **现代化架构**：Next.js 15 + React 19 + TypeScript
- **组件化设计**：基于shadcn/ui的可复用组件系统
- **状态管理**：React Hooks + 本地状态管理
- **样式系统**：Tailwind CSS + CSS变量主题系统
- **文件处理**：支持多格式文件导入和解析
- **性能优化**：代码分割、懒加载、图片优化

## 🛠️ 技术栈

### Web版本
- **框架**: [Next.js 15](https://nextjs.org/) - React全栈框架
- **语言**: [TypeScript](https://www.typescriptlang.org/) - 类型安全的JavaScript
- **UI框架**: [React 19](https://react.dev/) - 用户界面库
- **样式**: [Tailwind CSS](https://tailwindcss.com/) - 实用优先的CSS框架
- **组件库**: [shadcn/ui](https://ui.shadcn.com/) - 现代化React组件库
- **图标**: [Lucide React](https://lucide.dev/) - 美观的图标库
- **文件处理**: [XLSX](https://github.com/SheetJS/sheetjs) - Excel文件解析
- **表单**: [React Hook Form](https://react-hook-form.com/) + [Zod](https://zod.dev/) - 表单验证
- **主题**: [next-themes](https://github.com/pacocoursey/next-themes) - 主题切换
- **动画**: [tailwindcss-animate](https://github.com/jamiebuilds/tailwindcss-animate) - CSS动画
- **通知**: [Sonner](https://sonner.emilkowal.ski/) - Toast通知组件

### Flutter版本（开发中）
- **框架**: [Flutter](https://flutter.dev/) - 跨平台移动开发框架
- **语言**: [Dart](https://dart.dev/) - Google开发的编程语言
- **版本**: Flutter SDK ^3.8.1

## 🚀 快速开始

### 环境要求

#### Web版本
- **Node.js**: 18.0+ 
- **包管理器**: pnpm 8+ (推荐) 或 npm/yarn
- **浏览器**: 支持现代浏览器 (Chrome 90+, Firefox 88+, Safari 14+)

#### Flutter版本
- **Flutter SDK**: 3.8.1+
- **Dart SDK**: 3.0+
- **开发工具**: Android Studio 或 VS Code

### Web版本安装与运行

#### 1. 克隆项目
```bash
git clone <repository-url>
cd word-match-game
```

#### 2. 安装依赖
```bash
pnpm install
# 或者使用 npm
npm install
```

#### 3. 开发模式
```bash
pnpm dev
# 或者
npm run dev
```
访问 http://localhost:3000 查看应用

#### 4. 生产构建
```bash
pnpm build
pnpm start
# 或者
npm run build
npm run start
```

### Flutter版本运行

#### 1. 进入Flutter项目目录
```bash
cd word_match_game_flutter
```

#### 2. 获取依赖
```bash
flutter pub get
```

#### 3. 运行应用
```bash
flutter run
```

## 📖 使用说明

### 游戏流程

#### 1. 选择单词列表
- **内置列表**：
  - `Word A` - 基础词汇（200+单词）
  - `Word AA` - 进阶基础词汇（200+单词）
  - `Word B` - 中级词汇（300+单词）
  - `Word C` - 高级词汇（400+单词）
  - `Fry Word Lists` - 常用高频词汇（600+单词）
- **自定义导入**：支持JSON和Excel格式文件

#### 2. 游戏设置
- 调整配对数量：5-50对（可根据难度需求选择）
- 系统会从选定词库中随机选择对应数量的单词对

#### 3. 开始游戏
- 点击 "Start Game" 按钮开始
- 计时器自动开始计时
- 所有卡片随机排列显示

#### 4. 游戏操作
- **选择卡片**：点击任意卡片进行选择
- **配对匹配**：选择两张卡片，系统自动判断是否匹配
- **成功反馈**：匹配成功时播放音效，卡片变为绿色
- **错误反馈**：匹配失败时卡片会震动提示
- **语音朗读**：点击英文单词卡片可听取发音

#### 5. 游戏完成
- 完成所有配对后显示总用时
- 提供 "Play Again" 按钮继续挑战
- 可选择相同或不同的单词列表重新开始

## 📝 自定义单词列表格式

### JSON格式
创建一个JSON文件，使用二维数组格式：

```json
[
  ["英文单词", "中文翻译"],
  ["hello", "你好"],
  ["world", "世界"],
  ["computer", "计算机"],
  ["programming", "编程"],
  ["javascript", "JavaScript语言"]
]
```

### Excel格式
创建Excel文件（.xlsx），包含两列数据：

| A列（英文单词） | B列（中文翻译） |
|----------------|----------------|
| hello          | 你好           |
| world          | 世界           |
| computer       | 计算机         |
| programming    | 编程           |
| javascript     | JavaScript语言 |

**注意事项**：
- 第一行可以是标题行，系统会自动识别
- 确保每行都有英文和中文对应
- 支持特殊字符和标点符号
- 建议单词数量在10-200对之间以获得最佳游戏体验

## 📁 项目结构

```
word-match-game/
├── 📁 app/                          # Next.js 15 App Router
│   ├── 📄 page.tsx                  # 主游戏页面（2500+行核心逻辑）
│   ├── 📄 layout.tsx                # 根布局组件
│   └── 📄 globals.css               # 全局样式和CSS变量
├── 📁 components/                   # React组件库
│   ├── 📁 ui/                       # shadcn/ui组件集合（40+组件）
│   │   ├── 📄 button.tsx            # 按钮组件
│   │   ├── 📄 card.tsx              # 卡片组件
│   │   ├── 📄 dialog.tsx            # 对话框组件
│   │   ├── 📄 dropdown-menu.tsx     # 下拉菜单
│   │   ├── 📄 slider.tsx            # 滑块组件
│   │   └── 📄 ...                   # 其他UI组件
│   └── 📄 theme-provider.tsx        # 主题上下文提供者
├── 📁 hooks/                        # 自定义React Hooks
│   ├── 📄 use-mobile.tsx            # 移动端检测Hook
│   └── 📄 use-toast.ts              # Toast通知Hook
├── 📁 lib/                          # 工具函数库
│   └── 📄 utils.ts                  # 通用工具函数
├── 📁 public/                       # 静态资源
│   ├── 📄 placeholder-logo.png      # 占位图片
│   └── 📄 ...                       # 其他静态文件
├── 📁 styles/                       # 样式文件
│   └── 📄 globals.css               # 全局样式定义
├── 📁 word_match_game_flutter/      # Flutter移动端版本
│   ├── 📁 lib/                      # Flutter源码
│   ├── 📁 android/                  # Android平台配置
│   ├── 📄 pubspec.yaml              # Flutter依赖配置
│   └── 📄 README.md                 # Flutter项目说明
├── 📄 package.json                  # Node.js依赖和脚本
├── 📄 next.config.mjs               # Next.js配置
├── 📄 tailwind.config.ts            # Tailwind CSS配置
├── 📄 tsconfig.json                 # TypeScript配置
├── 📄 components.json               # shadcn/ui配置
└── 📄 README.md                     # 项目文档
```

### 核心文件说明

- **`app/page.tsx`**: 游戏主逻辑，包含完整的游戏状态管理、卡片匹配算法、计时器、音效等
- **`components/ui/`**: 基于Radix UI的现代化组件库，提供一致的用户体验
- **`tailwind.config.ts`**: 自定义主题配置，包含颜色系统、动画、响应式断点等
- **`next.config.mjs`**: Next.js优化配置，包含构建优化和部署设置

## 🔧 开发指南

### 代码规范
- 使用TypeScript进行类型安全开发
- 遵循ESLint和Prettier代码格式化规范
- 组件采用函数式组件 + Hooks模式
- 使用Tailwind CSS进行样式开发

### 主要依赖版本
- Next.js: 15.2.4
- React: 19.x
- TypeScript: 5.x
- Tailwind CSS: 3.4.17
- shadcn/ui: 最新版本

### 构建优化
- 启用图片优化和懒加载
- 代码分割和Tree Shaking
- 生产环境CSS压缩
- 静态资源CDN优化

## 🚀 部署

### Vercel部署（推荐）
```bash
# 安装Vercel CLI
npm i -g vercel

# 部署到Vercel
vercel
```

### 其他平台
- **Netlify**: 支持静态导出模式
- **Docker**: 提供容器化部署
- **传统服务器**: 支持Node.js环境部署

## 🤝 贡献指南

1. Fork本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- [Next.js](https://nextjs.org/) - 强大的React框架
- [shadcn/ui](https://ui.shadcn.com/) - 优秀的组件库
- [Tailwind CSS](https://tailwindcss.com/) - 实用的CSS框架
- [Radix UI](https://www.radix-ui.com/) - 无障碍UI原语
- [Lucide](https://lucide.dev/) - 美观的图标库

---

**开发者**: 如有问题或建议，欢迎提交Issue或Pull Request！