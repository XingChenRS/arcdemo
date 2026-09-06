// xrc-arcdemo / Tweak.x — bootstrap + 悬浮 UI/菜单。
// 游戏逻辑全部在 XRC* 模块；本文件只做装配、生命周期与 UI。
#define XRC_TWEAK_VERSION  @"v8.0.0"
#define XRC_BUILD_LABEL    @"Sideload"

#import <substrate.h>
#import <time.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/time.h>
#import <stdatomic.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "fishhook.h"
#import "XRCFloatButton.h"
#import "WHToast/WHToast.h"

#include "XRCProfile.h"
#include "XRCRuntime.h"
#include "XRCClock.h"
#include "XRCPlayer.h"
#include "XRCGameplay.h"
#include "XRCJudge.h"
#include "XRCConfig.h"

extern UIApplication *UIApp;

void acc_flog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);

#pragma mark - 全局 UI 状态（配置快照 + 控件）

static xrc_config_t g_cfg = {0};
XRCFloatButton *button = nil;   // AccCommon.h extern（UI hook 引用）
UIView        *menuView = nil;

#pragma mark - 主程序定位（唯一跨模块的 image base 实现）

uint64_t xrc_image_base(void) {
    static uint64_t cached = 0;
    if (cached) return cached;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, ".dylib") != NULL) continue;
        const char *slash = strrchr(name, '/');
        if (slash && strcmp(slash + 1, "Arc-mobile") == 0) {
            cached = (uint64_t)_dyld_get_image_header(i);
            break;
        }
    }
    if (!cached && n > 0)
        cached = (uint64_t)_dyld_get_image_header(0);
    return cached;
}

#pragma mark - 菜单（UI 逻辑，配置读写走 XRCConfig）

@interface AccMenuController : NSObject
+ (instancetype)shared;
- (void)show;
- (void)hide;
- (void)rebuild;
@property (nonatomic, strong) NSTimer *progressTimer;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, assign) BOOL userDraggingSlider;
@end

@implementation AccMenuController

+ (instancetype)shared {
    static AccMenuController *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [AccMenuController new]; });
    return s;
}

- (UIWindow *)keyWindow {
    if ([UIApp.delegate respondsToSelector:@selector(window)]) {
        UIWindow *w = [UIApp.delegate performSelector:@selector(window)];
        if (w) return w;
    }
    for (UIWindow *w in UIApp.windows) if (w.isKeyWindow) return w;
    return UIApp.windows.firstObject;
}

- (void)show {
    UIWindow *w = [self keyWindow];
    if (!w) {
        for (UIWindow *win in UIApp.windows) {
            if (!win.hidden) { w = win; break; }
        }
    }
    if (!w) {
        acc_flog(@"show: no window");
        return;
    }
    if (menuView) [menuView removeFromSuperview];
    menuView = [[UIView alloc] initWithFrame:w.bounds];
    menuView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    menuView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(backgroundTap:)];
    [menuView addGestureRecognizer:tap];
    [w addSubview:menuView];
    [w bringSubviewToFront:menuView];
    [self rebuild];
}

- (void)hide {
    [self.progressTimer invalidate];
    self.progressTimer = nil;
    self.progressSlider = nil;
    self.progressLabel = nil;
    [menuView removeFromSuperview];
    menuView = nil;
}

- (void)backgroundTap:(UITapGestureRecognizer *)g {
    CGPoint p = [g locationInView:menuView];
    UIView *card = [menuView viewWithTag:9001];
    if (!card || CGRectContainsPoint(card.frame, p)) return;
    [self hide];
}

- (void)rebuild {
    if (!menuView) return;
    for (UIView *sub in [menuView.subviews copy]) [sub removeFromSuperview];

    CGFloat W = MIN(menuView.bounds.size.width - 40, 320);
    CGFloat X = (menuView.bounds.size.width - W) / 2;

    UIScrollView *card = [[UIScrollView alloc] initWithFrame:CGRectMake(X, 80, W, menuView.bounds.size.height - 160)];
    card.tag = 9001;
    card.backgroundColor = [UIColor colorWithWhite:1 alpha:0.95];
    card.layer.cornerRadius = 12;
    card.layer.masksToBounds = YES;
    [menuView addSubview:card];

    CGFloat y = 12;
    CGFloat innerW = W - 24;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, y, innerW, 24)];
    title.text = [NSString stringWithFormat:@"ArcDemo %@ [%@]",
                  XRC_TWEAK_VERSION, XRC_BUILD_LABEL];
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textColor = [UIColor blackColor];
    [card addSubview:title];
    y += 28;

    UILabel *scope = [[UILabel alloc] initWithFrame:CGRectMake(12, y, innerW, 44)];
    scope.text = @"Chart + visual speed control; BGM stays 1.0x. Config: Documents/xrc-arcdemo.plist";
    scope.font = [UIFont systemFontOfSize:11];
    scope.textColor = [UIColor darkGrayColor];
    scope.numberOfLines = 0;
    [card addSubview:scope];
    y += 48;

    BOOL playerReady = (xrc_player_get() != NULL);

    UILabel *playerHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, y, innerW, 18)];
    playerHdr.text = playerReady ? @"Seek" : @"Seek (waiting for gameplay...)";
    playerHdr.font = [UIFont systemFontOfSize:13];
    playerHdr.textColor = [UIColor darkGrayColor];
    [card addSubview:playerHdr];
    y += 22;

    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(12, y, innerW, 28)];
    sl.minimumValue = 0;
    uint32_t maxMs = MAX(xrc_player_song_length_ms(), (uint32_t)1000);
    sl.maximumValue = (float)maxMs;
    sl.value = (float)xrc_player_position_ms();
    sl.continuous = YES;
    sl.enabled = playerReady;
    [sl addTarget:self action:@selector(sliderTouchDown:) forControlEvents:UIControlEventTouchDown];
    [sl addTarget:self action:@selector(sliderTouchUp:)   forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [card addSubview:sl];
    self.progressSlider = sl;
    y += 32;

    UILabel *posLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, y, innerW, 16)];
    posLbl.font = [UIFont systemFontOfSize:11];
    posLbl.textColor = [UIColor darkGrayColor];
    posLbl.textAlignment = NSTextAlignmentCenter;
    posLbl.text = @"--:-- / --:--";
    [card addSubview:posLbl];
    self.progressLabel = posLbl;
    y += 22;

    [self.progressTimer invalidate];
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                          target:self
                                                        selector:@selector(progressTick:)
                                                        userInfo:nil
                                                         repeats:YES];

    UILabel *toastLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, y, innerW - 60, 28)];
    toastLbl.text = @"Show speed toast";
    toastLbl.font = [UIFont systemFontOfSize:14];
    toastLbl.textColor = [UIColor blackColor];
    [card addSubview:toastLbl];
    UISwitch *toastSw = [[UISwitch alloc] initWithFrame:CGRectZero];
    CGSize swSize = toastSw.bounds.size;
    toastSw.frame = CGRectMake(W - 12 - swSize.width, y, swSize.width, swSize.height);
    toastSw.on = g_cfg.toast;
    [toastSw addTarget:self action:@selector(toastChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:toastSw];
    y += MAX(28, swSize.height) + 8;

    UILabel *judgeHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, y, innerW, 32)];
    judgeHdr.text = @"Judgement window +/-ms (Max / Pure / Far / Lost)";
    judgeHdr.font = [UIFont systemFontOfSize:12];
    judgeHdr.textColor = [UIColor darkGrayColor];
    judgeHdr.numberOfLines = 2;
    [card addSubview:judgeHdr];
    y += 34;

    const char *judgeTags[] = { "Max", "Pure", "Far", "Lost" };
    int judgeVals[] = { g_cfg.judge_max_ms, g_cfg.judge_pure_ms, g_cfg.judge_far_ms, g_cfg.judge_lost_ms };
    CGFloat colW = (innerW - 8) / 4.0f;
    for (int j = 0; j < 4; j++) {
        CGFloat cx = 12 + colW * j;
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(cx, y, colW - 4, 14)];
        lbl.text = @(judgeTags[j]);
        lbl.font = [UIFont systemFontOfSize:10];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.textColor = [UIColor grayColor];
        [card addSubview:lbl];

        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(cx, y + 16, colW - 4, 32)];
        tf.borderStyle = UITextBorderStyleRoundedRect;
        tf.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular];
        tf.textAlignment = NSTextAlignmentCenter;
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.text = [NSString stringWithFormat:@"%d", judgeVals[j]];
        tf.tag = 4100 + j;
        tf.delegate = (id<UITextFieldDelegate>)self;
        [card addSubview:tf];
    }
    y += 52;

    UILabel *speedHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, y, innerW, 18)];
    speedHdr.text = @"Speed presets (tap to select, long-press to delete)";
    speedHdr.font = [UIFont systemFontOfSize:12];
    speedHdr.textColor = [UIColor darkGrayColor];
    speedHdr.numberOfLines = 0;
    [card addSubview:speedHdr];
    y += 32;

    NSMutableDictionary *prefs = xrc_config_dict();
    NSArray *keys = prefs[@"speedKeys"];
    for (NSInteger i = 0; i < (NSInteger)keys.count; i++) {
        NSString *k = keys[i];
        float v = [prefs[k] floatValue];

        UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem];
        row.frame = CGRectMake(12, y, innerW - 60, 32);
        row.tag = 1000 + i;
        [row setTitle:[NSString stringWithFormat:@"  %.3fx", v] forState:UIControlStateNormal];
        row.titleLabel.font = [UIFont systemFontOfSize:15];
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.backgroundColor = (i == g_cfg.rate_index) ? [UIColor colorWithRed:0.9 green:0.95 blue:1 alpha:1] : [UIColor clearColor];
        row.layer.cornerRadius = 6;
        [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
            initWithTarget:self action:@selector(rowLongPress:)];
        [row addGestureRecognizer:lp];
        [card addSubview:row];

        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(W - 12 - 56, y, 56, 32)];
        tf.borderStyle = UITextBorderStyleRoundedRect;
        tf.font = [UIFont systemFontOfSize:13];
        tf.text = [NSString stringWithFormat:@"%.2f", v];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.textAlignment = NSTextAlignmentCenter;
        tf.tag = 2000 + i;
        tf.delegate = (id<UITextFieldDelegate>)self;
        [card addSubview:tf];

        y += 38;
    }

    UIButton *addBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addBtn.frame = CGRectMake(12, y, innerW, 32);
    [addBtn setTitle:@"+ Add speed" forState:UIControlStateNormal];
    [addBtn addTarget:self action:@selector(addSpeed) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:addBtn];
    y += 40;

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(12, y, innerW, 32);
    [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:closeBtn];
    y += 40;

    card.contentSize = CGSizeMake(W, y + 12);
}

- (void)sliderTouchDown:(UISlider *)s { self.userDraggingSlider = YES; }
- (void)sliderTouchUp:(UISlider *)s {
    self.userDraggingSlider = NO;
    xrc_seek_ms((uint32_t)s.value);
}

- (void)progressTick:(NSTimer *)t {
    if (!menuView) { [t invalidate]; self.progressTimer = nil; return; }
    uint32_t cur = xrc_player_position_ms();
    uint32_t maxMs = MAX(xrc_player_song_length_ms(), (uint32_t)1000);
    UISlider *sl = self.progressSlider;
    UILabel *lbl = self.progressLabel;
    if (sl) {
        if (sl.maximumValue < (float)maxMs) sl.maximumValue = (float)maxMs;
        if (!self.userDraggingSlider) sl.value = (float)cur;
        if (!sl.enabled && xrc_player_get()) sl.enabled = YES;
    }
    if (lbl) {
        uint32_t cs = cur / 1000u, ms = cur % 1000u;
        uint32_t ts = maxMs / 1000u;
        lbl.text = [NSString stringWithFormat:@"%02u:%02u.%03u / %02u:%02u",
                    cs / 60u, cs % 60u, ms,
                    ts / 60u, ts % 60u];
    }
}

- (void)toastChanged:(UISwitch *)s {
    g_cfg.toast = s.on;
    xrc_config_save(&g_cfg);
}

- (void)commitJudgeField:(UITextField *)tf {
    int v = MAX(0, [tf.text intValue]);
    switch (tf.tag - 4100) {
        case 0: g_cfg.judge_max_ms = v; break;
        case 1: g_cfg.judge_pure_ms = v; break;
        case 2: g_cfg.judge_far_ms = v; break;
        case 3: g_cfg.judge_lost_ms = v; break;
        default: return;
    }
    xrc_config_normalize_judge(&g_cfg);
    tf.text = [NSString stringWithFormat:@"%d",
               (tf.tag == 4100) ? g_cfg.judge_max_ms :
               (tf.tag == 4101) ? g_cfg.judge_pure_ms :
               (tf.tag == 4102) ? g_cfg.judge_far_ms : g_cfg.judge_lost_ms];
    xrc_config_save(&g_cfg);
    xrc_judge_set_windows(g_cfg.judge_max_ms, g_cfg.judge_pure_ms,
                          g_cfg.judge_far_ms, g_cfg.judge_lost_ms);
    if (g_cfg.toast) {
        [WHToast showMessage:[NSString stringWithFormat:@"Judgement params saved: +/- %d/%d/%d/%d",
                              g_cfg.judge_max_ms, g_cfg.judge_pure_ms,
                              g_cfg.judge_far_ms, g_cfg.judge_lost_ms]
                    duration:0.8 finishHandler:^{}];
    }
}

- (void)rowTapped:(UIButton *)b {
    NSInteger i = b.tag - 1000;
    if (i < 0 || i >= g_cfg.speed_count) return;
    g_cfg.rate_index = i;
    xrc_clock_set_rate((double)g_cfg.speeds[g_cfg.rate_index]);
    xrc_config_save(&g_cfg);
    if (g_cfg.toast) {
        [WHToast showMessage:[NSString stringWithFormat:@"%.3fx", g_cfg.speeds[g_cfg.rate_index]]
                               duration:0.5 finishHandler:^{}];
    }
    [self rebuild];
}

- (void)rowLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    NSInteger i = g.view.tag - 1000;
    if (i < 0) return;
    NSMutableDictionary *p = xrc_config_dict();
    NSMutableArray *keys = [p[@"speedKeys"] mutableCopy];
    if (i >= (NSInteger)keys.count) return;
    if (keys.count <= 1) return; // Keep at least one preset.
    NSString *k = keys[i];
    [keys removeObjectAtIndex:i];
    [p removeObjectForKey:k];
    p[@"speedKeys"] = keys;
    xrc_config_write_dict(p);
    xrc_config_load(&g_cfg);
    [self rebuild];
}

- (void)addSpeed {
    NSMutableDictionary *p = xrc_config_dict();
    NSMutableArray *keys = [p[@"speedKeys"] mutableCopy];
    NSInteger n = 1;
    NSString *nk;
    do { nk = [NSString stringWithFormat:@"speed-%ld", (long)n++]; } while ([keys containsObject:nk]);
    [keys addObject:nk];
    p[nk] = @1.0;
    p[@"speedKeys"] = keys;
    xrc_config_write_dict(p);
    xrc_config_load(&g_cfg);
    [self rebuild];
}

// UITextFieldDelegate
- (void)textFieldDidEndEditing:(UITextField *)tf {
    if (tf.tag >= 4100 && tf.tag <= 4103) {
        [self commitJudgeField:tf];
        return;
    }
    NSInteger i = tf.tag - 2000;
    if (i < 0 || i >= g_cfg.speed_count) return;
    float v = MAX(0.0f, MIN(100.0f, [tf.text floatValue]));
    NSMutableDictionary *p = xrc_config_dict();
    NSArray *keys = p[@"speedKeys"];
    if (i >= (NSInteger)keys.count) return;
    p[keys[i]] = @(v);
    xrc_config_write_dict(p);
    xrc_config_load(&g_cfg);
}
- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    [tf resignFirstResponder];
    return YES;
}

@end

#pragma mark - UI overlay

%group ui
%hook NSBundle
+ (NSBundle *)bundleForClass:(Class)aClass {
    if (aClass == [%c(WHToastView) class]) {
        NSBundle *main = [NSBundle mainBundle];
        return main ?: %orig;
    }
    return %orig;
}
%end

%hook UIWindow
- (void)bringSubviewToFront:(UIView *)view {
    %orig;
    if (view == button || view == menuView) return;
    if (button) %orig(button);
    if (menuView) %orig(menuView);
}
- (void)addSubview:(UIView *)view {
    %orig;
    if (view == button || view == menuView) return;
    if (button) [self bringSubviewToFront:button];
    if (menuView) [self bringSubviewToFront:menuView];
}
%end
%end

#pragma mark - floating button bootstrap

static void initButton(void) {
    [WHToast setShowMask:NO];
    button = [XRCFloatButton shared];
    // 单击 = 打开菜单（修复：原双击手势与 WQSuspendView 冲突打不开）
    button.onTap = ^{
        [[AccMenuController shared] show];
    };
    // 长按 = 切换速度预设（原单击行为）
    button.onLongPress = ^{
        if (g_cfg.speed_count <= 0) return;
        g_cfg.rate_index = (g_cfg.rate_index + 1) % g_cfg.speed_count;
        xrc_clock_set_rate((double)g_cfg.speeds[g_cfg.rate_index]);
        xrc_config_save(&g_cfg);
        if (g_cfg.toast) {
            [WHToast showMessage:[NSString stringWithFormat:@"%.3fx (tap opens menu)", g_cfg.speeds[g_cfg.rate_index]]
                                       duration:0.5 finishHandler:^{}];
        }
    };
    UIWindow *w = [[AccMenuController shared] keyWindow];
    [button attachToWindow:w];
    if (!g_cfg.button_enabled) [button setHiddenState:YES];
}

@interface AccMenuController (MenuGesture) @end
@implementation AccMenuController (MenuGesture)
- (void)handleDoubleTap:(UITapGestureRecognizer *)g {
    [self show];
}
@end

#pragma mark - bootstrap

// 文件日志（侧载下 Console 不便）。
void acc_flog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[xrc-arcdemo] %@", line);
    @try {
        NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if (!docs) return;
        NSString *path = [docs stringByAppendingPathComponent:@"xrc-arcdemo.log"];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        NSString *out = [NSString stringWithFormat:@"[%@] %@\n", [df stringFromDate:[NSDate date]], line];
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) {
            [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        } else {
            [fh seekToEndOfFile];
            [fh writeData:[out dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        }
    } @catch (NSException *e) {}
}

static void doBootstrap(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        acc_flog(@"==== xrc-arcdemo tweak %@ doBootstrap begin ====", XRC_TWEAK_VERSION);
        uint64_t base = xrc_image_base();
        g_xrc = xrc_runtime_discover();
        @try { initButton(); }       @catch (NSException *e) { acc_flog(@"initButton EX: %@", e); }
        @try { xrc_player_install(base); }      @catch (NSException *e) { acc_flog(@"player EX: %@", e); }
        @try { xrc_gameplay_install_hooks(base); } @catch (NSException *e) { acc_flog(@"gameplay EX: %@", e); }
        @try { xrc_judge_install(base); }       @catch (NSException *e) { acc_flog(@"judge EX: %@", e); }
        @try {
            static dispatch_once_t tw_once;
            dispatch_once(&tw_once, ^{
                struct rebinding rs[1] = {
                    { "gettimeofday", (void *)xrc_clock_gettimeofday, (void **)&xrc_clock_orig_gettimeofday },
                };                rebind_symbols(rs, 1);
            });
        } @catch (NSException *e) { acc_flog(@"timewarp EX: %@", e); }
        if (g_cfg.speed_count > 0)
            xrc_clock_set_rate((double)g_cfg.speeds[g_cfg.rate_index]);
        acc_flog(@"config path: %@", xrc_config_path());
        [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
            void *p = xrc_player_get();
            if (xrc_player_detect_change(p)) {
                acc_flog(@"new song: player=%p", p);
            }
            if (p) xrc_player_try_capture_length(p);
        }];
        acc_flog(@"doBootstrap done");
    });
}

static void onAppDidEnterBackground(CFNotificationCenterRef center, void *observer,
                                    CFStringRef name, const void *object,
                                    CFDictionaryRef userInfo) {
    xrc_clock_freeze_inc();
    acc_flog(@"app -> background, warp frozen (count=%d)", xrc_clock_freeze_count());
}

static void onAppWillEnterForeground(CFNotificationCenterRef center, void *observer,
                                     CFStringRef name, const void *object,
                                     CFDictionaryRef userInfo) {
    xrc_clock_freeze_dec();
    acc_flog(@"app -> foreground, warp unfrozen (count=%d)", xrc_clock_freeze_count());
}

static void onAppLaunched(CFNotificationCenterRef center, void *observer,
                          CFStringRef name, const void *object,
                          CFDictionaryRef userInfo) {
    acc_flog(@"onAppLaunched notification fired");
    doBootstrap();
}

%ctor {
    acc_flog(@"ctor entered (dylib loaded ok)");
    @try { %init(ui); }   @catch (NSException *e) { acc_flog(@"%%init(ui) EX: %@", e); }
    @try { xrc_config_load(&g_cfg); }  @catch (NSException *e) { acc_flog(@"config EX: %@", e); }
    @try {
        xrc_judge_set_windows(g_cfg.judge_max_ms, g_cfg.judge_pure_ms,
                              g_cfg.judge_far_ms, g_cfg.judge_lost_ms);
    } @catch (NSException *e) {}
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL,
        onAppLaunched,
        (CFStringRef)UIApplicationDidFinishLaunchingNotification,
        NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL,
        onAppDidEnterBackground,
        (CFStringRef)UIApplicationDidEnterBackgroundNotification,
        NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL,
        onAppWillEnterForeground,
        (CFStringRef)UIApplicationWillEnterForegroundNotification,
        NULL, CFNotificationSuspensionBehaviorCoalesce);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        acc_flog(@"3s fallback bootstrap");
        doBootstrap();
    });
}
