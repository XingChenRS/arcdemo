// XRCFloatButton.h — 自绘悬浮窗：单击开菜单、长按切速度、可拖拽。
// 替代 WQSuspendView（其 UITapGestureRecognizer 与自定义双击手势冲突导致
// 菜单打不开；且自绘纯色背景显示异常）。图标为 base64 内嵌 JPEG。
#pragma once

#import <UIKit/UIKit.h>

@interface XRCFloatButton : UIView

+ (instancetype)shared;

// block：单击 = 打开菜单；长按 = 切换速度预设。
@property (nonatomic, copy) void (^onTap)(void);
@property (nonatomic, copy) void (^onLongPress)(void);

- (void)attachToWindow:(UIWindow *)window;
- (void)setHiddenState:(BOOL)hidden;

@end
