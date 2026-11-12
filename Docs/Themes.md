# 主题

商店的「主题」展示可购买主题。购买使用铜纳特余额结算；已拥有的主题在设置的「主题」页选择，原版始终可用。

| 主题 | 解锁等级 | 价格 |
| --- | ---: | ---: |
| Y2K | 5 | 8 银西可 |
| 液态玻璃 | 8 | 1 金加隆 |
| 圣诞 | 12 | 2 金加隆 |

主题覆盖管理界面、桌宠菜单和徽标、模块窗口、表单、日历、按钮、图标、滚动条、提示和台词框。场景、物品及角色素材使用游戏资源。

Y2K 使用切角面板、银色金属按键、深色显示区及铬色图标。液态玻璃采用浅色内容区、悬浮侧栏、胶囊控件及简洁符号；macOS 26 及以上使用系统 Liquid Glass，较早系统和「减少透明度」模式使用实色控件。圣诞采用暖纸色内容、深红标签、缝线边缘及冬青与缎带装饰。

界面材质参考 [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials) 和 [Liquid Glass 自定义控件](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)。金属控件参考 [Winamp Cell](https://www.wincustomize.com/explore/winamp/1728/) 的分层结构；节庆纸品参考 [V&A 圣诞贺卡馆藏](https://www.vam.ac.uk/articles/the-first-christmas-card)。

主题所有权保存在 `garden.economy.ownedThemes`，当前选择保存在 `preferences.selectedTheme`。缺少这两个字段的存档使用原版。购买和选择由存档事务提交；保存失败时恢复原状态。
