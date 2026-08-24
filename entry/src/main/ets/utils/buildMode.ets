// 构建模式常量（源码级）：替代 hvigor 构建期生成的 'BuildProfile' 模块，
// 让 ArkTSCheck / IDE 也能直接解析，消除 "Cannot find module 'BuildProfile'" 报错。
// 发布前把两者改成 release 形态：BUILD_MODE_NAME = 'release'，DEBUG = false。
export const BUILD_MODE_NAME: string = 'debug';
export const DEBUG: boolean = true;