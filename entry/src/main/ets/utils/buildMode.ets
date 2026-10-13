// 构建模式常量（源码级）：替代 hvigor 构建期生成的 'BuildProfile' 模块，
// 让 ArkTSCheck / IDE 也能直接解析，消除 "Cannot find module 'BuildProfile'" 报错。
// 发布上架形态：BUILD_MODE_NAME = 'release'，DEBUG = false（release 下测试登录桩自动隐藏）。
export const BUILD_MODE_NAME: string = 'release';
// DEBUG=true → 后端走本地调试后端 http://127.0.0.1:3000（需先建 hdc rport：hdc -t <设备> rport tcp:3000 tcp:3000）
// DEBUG=false → 后端走线上 https://api.youju.chat（DNS：youju.chat→114.132.102.189）。
// ⚠️ 本地联调验证完毕后务必还原为 false 再上架。
export const DEBUG: boolean = false;
// 对外展示的版本名：与 AppScope/app.json5 的 versionName 同步改，UI 只从这里取值。
// 此前 AboutPage 与 SettingsPage 各写一份字面量，1.0.3 发版时设置页那行漏改成了 1.0.1。
export const APP_VERSION_NAME: string = '1.0.3';