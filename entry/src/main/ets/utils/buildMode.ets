// 构建模式常量（源码级）：替代 hvigor 构建期生成的 'BuildProfile' 模块，
// 让 ArkTSCheck / IDE 也能直接解析，消除 "Cannot find module 'BuildProfile'" 报错。
// 发布上架形态：BUILD_MODE_NAME = 'release'，DEBUG = false（release 下测试登录桩自动隐藏）。
export const BUILD_MODE_NAME: string = 'release';
// DEBUG=true → 后端走本地调试后端 http://10.181.227.205:3000（本机 LAN IP，真机/模拟器联调）
// DEBUG=false → 后端走线上 https://api.youju.chat（DNS：youju.chat→114.132.102.189）。
// ⚠️ 本地联调验证完毕后务必还原为 false 再上架。
export const DEBUG: boolean = false;