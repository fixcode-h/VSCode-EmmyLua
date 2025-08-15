import { basename } from 'path';
import * as vscode from 'vscode';
import * as cp from "child_process";
import * as iconv from 'iconv-lite';
import { DebugConfigurationBase } from "../base/DebugConfigurationBase";
import { DebuggerProvider } from "../base/DebuggerProvider";

interface ProcessInfoItem extends vscode.QuickPickItem {
    pid: number;
}

export interface EmmyAttachDebugConfiguration extends DebugConfigurationBase {
    pid: number;
    processName: string;
}


export class EmmyAttachDebuggerProvider extends DebuggerProvider {
    async resolveDebugConfiguration(folder: vscode.WorkspaceFolder | undefined, configuration: EmmyAttachDebugConfiguration, token?: vscode.CancellationToken): Promise<vscode.DebugConfiguration> {
        configuration.extensionPath = this.context.extensionPath;
        configuration.sourcePaths = this.getSourceRoots();
        configuration.request = "attach";
        configuration.type = "emmylua_attach";
        configuration.ext = this.getExt();
        configuration.processName = configuration.processName ?? ""
        if (configuration.pid > 0) {
            return configuration;
        }

        const pid = await this.pickPID(configuration.processName);
        configuration.pid = pid;
        return configuration;
    }

    private async pickPID(processName: string) {
        return new Promise<number>((resolve, reject) => {
            const args = [`"${this.context.extensionPath}/debugger/emmy/windows/x86/emmy_tool.exe"`, "list_processes"];
            cp.exec(args.join(" "), { encoding: 'buffer' }, (_err, stdout, _stderr) => {
                const str = iconv.decode(stdout, "cp936");
                const arr = str.split('\r\n');
                const size = Math.floor(arr.length / 4);
                const items: ProcessInfoItem[] = [];
                
                // 获取调试配置
                const config = vscode.workspace.getConfiguration('emmylua');
                const filterUEProcesses = config.get<boolean>('debug.filterUEProcesses', false);
                const autoAttachSingleProcess = config.get<boolean>('debug.autoAttachSingleProcess', true);
                
                // 从配置中获取线程过滤黑名单
                const threadFilterBlacklist = config.get<string[]>('debug.threadFilterBlacklist', []);
                
                for (let i = 0; i < size; i++) {
                    const pid = parseInt(arr[i * 4]);
                    const title = arr[i * 4 + 1];
                    const path = arr[i * 4 + 2];
                    const name = basename(path);
                    
                    // 检查是否为UE进程
                    const isUEProcess = this.isUnrealEngineProcess(name, path, title);
                    
                    const item: ProcessInfoItem = {
                        pid: pid,
                        label: `${pid} : ${name}`,
                        description: title,
                        detail: path
                    };
                    
                    // 应用过滤逻辑
                    const matchesProcessName = processName.length === 0
                        || title.indexOf(processName) !== -1
                        || name.indexOf(processName) !== -1;
                    
                    // 检查是否在黑名单中
                    const isBlacklisted = threadFilterBlacklist.some(blacklistItem => 
                        name.includes(blacklistItem) || 
                        title.includes(blacklistItem) || 
                        path.includes(blacklistItem)
                    );
                    
                    const shouldInclude = matchesProcessName && (!filterUEProcesses || isUEProcess) && !isBlacklisted;
                    
                    if (shouldInclude) {
                        items.push(item);
                    }
                }
                if (items.length > 1) {
                    vscode.window.showQuickPick(items, {
                        matchOnDescription: true,
                        matchOnDetail: true,
                        placeHolder: "Select the process to attach"
                    }).then((item: ProcessInfoItem | undefined) => {
                        if (item) {
                            resolve(item.pid);
                        } else {
                            reject();
                        }
                    });
                } else if (items.length == 1) {
                    if (autoAttachSingleProcess) {
                        resolve(items[0].pid);
                    } else {
                        vscode.window.showQuickPick(items, {
                            matchOnDescription: true,
                            matchOnDetail: true,
                            placeHolder: "Select the process to attach"
                        }).then((item: ProcessInfoItem | undefined) => {
                            if (item) {
                                resolve(item.pid);
                            } else {
                                reject();
                            }
                        });
                    }
                } else {
                    vscode.window.showErrorMessage("No process for attach")
                    reject();
                }

            }).on("error", error => reject);
        });
    }

    /**
     * 判断是否为虚幻引擎进程
     * @param name 进程名称
     * @param path 进程路径
     * @param title 进程标题
     * @returns 是否为UE进程
     */
    private isUnrealEngineProcess(name: string, path: string, title: string): boolean {
        // 从配置中获取UE进程名称模式
        const config = vscode.workspace.getConfiguration('emmylua');
        const ueProcessNames = config.get<string[]>('debug.ueProcessNames', []);

        // 检查进程名称
        const lowerName = name.toLowerCase();
        if (ueProcessNames.some(ueName => lowerName.includes(ueName.toLowerCase()))) {
            return true;
        }

        return false;
    }
}
