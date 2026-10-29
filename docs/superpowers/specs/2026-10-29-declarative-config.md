# Aptenodytes 声明式配置层：第一阶段设计边界

日期：2026-10-29。记录当前讨论形成的共识；现有代码仍是验证原型。

定位：**Nix 消费 Gentoo 提供的系统应用和工具，生产声明式配置产物；Portage 和现有 profile 流程继续负责系统环境。**

## 已确定的四项原则

1. 使用 Nix 的整体框架：flake 输入、模块求值、配置合并、derivation 和 store。自有环境适配函数命名为 **`pseudoBuildEnv`**。
2. 替换传给模块的 `pkgs`，将应用映射到 Gentoo 原生路径。构建配置时也尽可能优先使用系统原生工具；Nix 在这里承担应用 consumer、配置 producer 的角色。
3. 尽量少修改 nixpkgs，按需导入模块，优先通过参数、选项合并和小适配层复用上游行为。兼容 Home Manager 等模块体系，以实际覆盖的模块为边界。
4. 最终 derivation 包含以文件系统根目录为基准的配置树及加载所需元数据，由自有 activation 脚本将它载入系统。配置和辅助脚本可以继续存放在 `/nix/store`。

第一阶段不让 Nix 接管 `burn.sh`、现有 profile 选择、包安装更新、ebuild 管理或 keep-in-sync。是否进一步整合包管理留待后续独立评估。

## 方案选择

本阶段采用“原生环境 + Nix 配置生成 + 自有 activation”。直接使用完整 NixOS/Home Manager 的环境构建和 activation，会同时接受更多上游包管理及系统布局约定；重新实现全部配置模块则会失去上游已有的类型、合并规则和生成逻辑。当前选择保留可复用的模块，明确系统环境与配置产物之间的接口。

## `pkgs` 与 `pseudoBuildEnv`

模块看到的原生包映射提供所需路径和少量属性，大部分前缀为 `/usr`，特殊程序单独声明。映射本身不负责安装软件，也不要求检查所有原生程序是否存在。

`pseudoBuildEnv` 的职责是构造符合模块预期的环境产物：

- 对原生包，根据声明的路径映射生成引用；允许目标在构建沙盒内不存在，不遍历宿主整个 `/usr` 来发现包文件。
- 对实际生成的 store 文件，保留并组合其内容。特别是 Home Manager 的 session variables、辅助脚本等，不能因跳过包安装而一并丢弃。
- 保持构建产物和运行环境分离；原生程序的实际可用性和版本由 Gentoo 环境负责。

具体支持哪些 `buildEnv` 参数、文件布局和覆盖规则，需要在实现时围绕已选模块确定。这个名称不意味着已经完整复刻上游 `buildEnv` 的全部行为。

## 原生构建工具与 sandbox

运行时路径引用与构建期执行是两个接口：把 `/usr/sbin/pppd` 写入 unit，不需要访问该文件；执行 YAML 转换器则需要真实可运行的工具及其依赖。

既定偏好是尽可能使用原生构建工具。接下来需要验证如何把它们显式提供给构建环境，包含解释器、动态链接器、库和必要资源。只读工具视图或工具快照都是可评估的实现方式，尚未选定。

不因为生成 `/usr` 引用而默认关闭 sandbox。Linux Nix sandbox 默认不暴露宿主 `/usr`；创建指向其中路径的软链无需开放它。真正执行原生工具时，需要单独解决沙盒可见性。原生工具不可用时是否允许特定 Nix 构建工具回退，也尚未确定。

flake 固定 nixpkgs 和其他模块源码；Home Manager 等输入可以通过 `follows` 共用 nixpkgs。宿主工具的版本不会因此被 flake.lock 自动固定，这是消费外部环境的边界。

此前原型使用真实 Nix 构建工具，并因云容器的 namespace 限制关闭了构建 sandbox。这些实验验证了模块与运行时路径的分离，尚未验证原生工具在严格沙盒中执行。

## 配置产物与 activation

产物应包含配置文件树、辅助脚本，以及记录文件所有权、服务启用关系和变更策略的 manifest。这里的 root 配置指 `/etc`、`/usr/lib` 等文件系统布局，不是 root 用户的 home 配置。

activation 负责按新旧产物更新受管理的链接、移除已退出管理的旧配置，并执行需要的 daemon-reload、启动、停止、reload 或 restart。清理范围限于自身管理的文件。网络设备配置的变更需要沿用或适配其特定行为，不能统一视为重启服务即可生效。

当前 generation 的提示链接可集中放在 `/etc/aptenodytes`；防止 GC 回收仍需向 Nix 注册 root。不依赖 `/run/current-system`，也不采用 NixOS 的 `switch-to-configuration`。

Gentoo 更新原生二进制不会改变配置 derivation 的 hash，继续以 needrestart 或等价机制补充服务重启检测。凭据等外部运行时文件保持外部引用。

Home Manager 接入时，文件生成、user units 和所选模块的必要 activation hook 一并纳入适配范围；仅提取配置文件不能自动等价于完整 HM activation。系统服务与用户服务分别在适当的权限和会话上下文加载。

## 已有证据与待验证范围

- 第一轮验证：完整 networkd 模块及 systemd 渲染库可不改源码复用；11 个网络文件与现有生成器规范化一致。
- PPP 验证：完整上游 `services.pppd` 加本地选项覆盖，可生成 peer、实例 unit、准备脚本和启用链接，保持现有配置行为。
- 本设计形成时尚未完成 `pseudoBuildEnv`、原生构建工具沙盒接入、Home Manager 实际构建，以及系统 activation 的实现与运行验证。最新实现和验证状态见 [构建文档](../../../nix/README.md)。

下一轮适合围绕 `pseudoBuildEnv` 验证一个同时包含原生应用引用、YAML 生成工具和 HM 自有生成文件的最小案例。它用于确认上述边界，不扩展到系统包管理。
