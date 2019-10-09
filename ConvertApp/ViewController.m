//
//  ViewController.m
//  ConvertApp
//
//  Created by zhongqing on 2019/9/27.
//  Copyright © 2019 ZQing. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSButton *searchBtn;
@property (weak) IBOutlet NSButton *suffix_m;
@property (weak) IBOutlet NSButton *suffix_h;
@property (weak) IBOutlet NSButton *suffix_mm;
@property (weak) IBOutlet NSButton *suffix_swift;
@property (weak) IBOutlet NSTableView *resultTable;
@property (weak) IBOutlet NSButton *exportDir;
@property (weak) IBOutlet NSButton *exportBtn;
@property (weak) IBOutlet NSTextField *exportField;

@property (weak) IBOutlet NSTableHeaderView *resultHeader;
@property (weak) IBOutlet NSTextField *ignoreFolderField;

@property (nonatomic, copy) NSString *projectPath;
@property (nonatomic, strong) NSMutableSet *suffixSet;       //要遍历的后缀文件名
@property (nonatomic, strong) NSMutableDictionary *keyValue; //中文对应的Key
@property (nonatomic, strong) NSMutableArray *keyAry;        //
@property (nonatomic, strong) NSMutableDictionary *valueKey; //value -  key(英文value 和key 都保持唯一)
@property (nonatomic, copy) NSArray *ignoreFolder;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _suffixSet = [NSMutableSet set];

    _keyValue = [NSMutableDictionary dictionary];
    _valueKey = [NSMutableDictionary dictionary];
    _keyAry = [NSMutableArray array];

    if (_suffix_m.state == NSControlStateValueOn) {
        [_suffixSet addObject:@".m"];
    }
    if (_suffix_h.state == NSControlStateValueOn) {
        [_suffixSet addObject:@".h"];
    }
    if (_suffix_mm.state == NSControlStateValueOn) {
        [_suffixSet addObject:@".mm"];
    }
    if (_suffix_swift.state == NSControlStateValueOn) {
        [_suffixSet addObject:@".swift"];
    }
    // Do any additional setup after loading the view.
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _keyAry.count;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    if (_keyAry.count > row) {
        NSString *key = _keyAry[row];
        if ([tableColumn.identifier isEqualToString:@"resultkey"]) {
            return key;
        } else if ([tableColumn.identifier isEqualToString:@"resultvalue"]) {
            return [_keyValue objectForKey:key];
        }
    }
    return @"";
}

//-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
//{
//    //表格列的标识
//    NSString *identifier = tableColumn.identifier;
//    //根据表格列的标识,创建单元视图
//    NSView *view = [tableView makeViewWithIdentifier:identifier owner:self];
//    NSArray *subviews = [view subviews];
//
//    if (subviews.count > 0) {
//
//    }
//    return view;
//}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)seletRootFolder:(NSButton *)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];

    NSWindow *window = [[NSApplication sharedApplication] keyWindow];

    __weak __typeof(self) weakSelf = self;
    [openPanel beginSheetModalForWindow:window
                      completionHandler:^(NSModalResponse returnCode) {
                        if (returnCode == 1) {
                            NSURL *fileUrl = [[openPanel URLs] objectAtIndex:0];
                            NSString *filePath = [[fileUrl.absoluteString componentsSeparatedByString:@"file://"] lastObject];
                            NSString *decodedString = (__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (__bridge CFStringRef)filePath, CFSTR(""), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));

                            weakSelf.projectPath = decodedString;
                            [weakSelf.textField setStringValue:decodedString];
                            NSString *exportPath = [decodedString stringByAppendingPathComponent:@"text.txt"];
                            [weakSelf.exportField setStringValue:exportPath];
                        }
                      }];
}

- (IBAction)startSearch:(id)sender {
    NSLog(@"seletRootFolder");

    _ignoreFolder = nil;
    NSString *ignoreString = _ignoreFolderField.stringValue;
    if (ignoreString.length > 0) {
        _ignoreFolder = [ignoreString componentsSeparatedByString:@";"];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (_projectPath.length <= 0) {
        [self showAlert:@"请选择项目工程地址"];
        return;
    }
    if (![fileManager fileExistsAtPath:_projectPath]) {
        [self showAlert:@"显示工程目录"];
        return;
    }

    if (_suffixSet.count == 0) {
        [self showAlert:@"请选择要查找文件的后缀名"];
        return;
    }

    //.m .mm
    NSString *pattern = @"\"[^\"]*[\u4E00-\u9FA5]+[^\"\n]*?\"";
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    if (error) {
        NSLog(@"Could't create regex with given string and options");
    }
    //.h .swift
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:_projectPath];
    NSString *filePath = nil;
    NSMutableSet *set = [[NSMutableSet alloc] init];
    NSMutableArray *chinaAry = [NSMutableArray array];
    [_keyValue removeAllObjects];
    [_valueKey removeAllObjects];
    [_keyAry removeAllObjects];

    while ((filePath = [enumerator nextObject]) != nil) {
        // 要查找的后缀名
        NSString *suffix = [filePath pathExtension];

        if (suffix.length > 0) {
            suffix = [@"." stringByAppendingString:suffix];
        }
        if ([_suffixSet containsObject:suffix]) {
            NSLog(@"filePath = %@", filePath);

            //含有需要过滤的文件夹(这里写法不是很好，总觉得可以用谓词快速过滤。不用循环查找)
            BOOL isIgnore = NO;
            NSString *fullPath = [_projectPath stringByAppendingString:filePath];
            for (NSString *floder in _ignoreFolder) {
                if ([fullPath containsString:[NSString stringWithFormat:@"/%@/",floder]]) {
                    isIgnore = YES;
                }
            }
            if (isIgnore) {
                continue;
            }

            filePath = [_projectPath stringByAppendingString:filePath];
            NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];

            NSArray *matches = [regex matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];

            NSString *relplacedString = content;

            for (int n = 0; n < matches.count; n++) {
                NSTextCheckingResult *obj = matches[n];

                NSString *china = [content substringWithRange:obj.range];

                NSRange range = [relplacedString rangeOfString:china];

                if (range.location != NSNotFound) {
                    if (![set containsObject:china]) {
                        [set addObject:china];
                        [chinaAry addObject:china];
                    } else {
                        continue;
                    }
                    NSUInteger nIndex = [chinaAry indexOfObject:china];

                    NSString *key = [NSString stringWithFormat:@"LPKey%lu", (unsigned long)nIndex];

                    [_keyValue setValue:china forKey:key];
                    [_keyAry addObject:key];
                    [_valueKey setValue:key forKey:china];
                }
            }
        }
    }

    if (_keyValue.count == 0) {
        [self showAlert:@"工程中没有中文"];
        [self.resultTable reloadData];
        return;
    }
    [self.resultTable reloadData];
    self.exportBtn.enabled = YES;
    self.exportDir.enabled = YES;
}

- (void)startReadTofile {
    NSString *tmpFile = [_exportField stringValue];
    if (!tmpFile) {
        [self showAlert:@"请输入导出路径"];
        return;
    }
    NSError *err;
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpFile error:&err];
    }

    NSString *willRead = @"";
    for (int n = 0; n < _keyValue.count; n++) {
        NSString *key = [@"LPKey" stringByAppendingFormat:@"%d", n];
        NSString *value = [_keyValue objectForKey:key];
        if ([value hasPrefix:@"@"]) {
            value = [value substringFromIndex:1];
        }
        willRead = [willRead stringByAppendingFormat:@"\"%@\"   =  %@\n", key, value];
    }

    BOOL isSuccess = [[NSFileManager defaultManager] createFileAtPath:tmpFile contents:[willRead dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];

    if (isSuccess) {
        [self showAlert:@"Success"];
    } else {
        [self showAlert:@"导出文件失败"];
    }
}

- (void)showAlert:(NSString *)text {
    if (text.length == 0) {
        return;
    }
    NSAlert *alert = [NSAlert new];
    [alert addButtonWithTitle:@"确定"];
    [alert setMessageText:text];
    [alert beginSheetModalForWindow:self.view.window
                  completionHandler:^(NSModalResponse returnCode){

                  }];
}

- (IBAction)clicksuffix_m:(NSButton *)sender {
    NSLog(@"clicksuffix_m%@", sender);
    if (sender.state == NSControlStateValueOn) {
        [_suffixSet addObject:@".m"];
    } else {
        [_suffixSet removeObject:@".m"];
    }
}
- (IBAction)clicksuffix_h:(NSButton *)sender {
    if (sender.state == NSControlStateValueOn) {
        [_suffixSet addObject:@".h"];
    } else {
        [_suffixSet removeObject:@".h"];
    }
}
- (IBAction)clickSuffix_mm:(NSButton *)sender {
    if (sender.state == NSControlStateValueOn) {
        [_suffixSet addObject:@".mm"];
    } else {
        [_suffixSet removeObject:@".mm"];
    }
}
- (IBAction)clickSuffix_swift:(NSButton *)sender {
    if (sender.state == NSControlStateValueOn) {
        [_suffixSet addObject:@".swift"];
    } else {
        [_suffixSet removeObject:@".swift"];
    }
}

- (IBAction)clickExportButton:(id)sender {
}

- (IBAction)startExport:(id)sender {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (_projectPath.length <= 0) {
        [self showAlert:@"请选择项目工程地址"];
        return;
    }
    if (![fileManager fileExistsAtPath:_projectPath]) {
        [self showAlert:@"显示工程目录"];
        return;
    }

    if (_suffixSet.count == 0) {
        [self showAlert:@"请选择要查找文件的后缀名"];
        return;
    }
    //.m .mm
    NSString *pattern = @"@\"[^\"]*[\u4E00-\u9FA5]+[^\"\n]*?\"";
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];

    if (error) {
        NSLog(@"Could't create regex with given string and options");
    }

    NSRegularExpression *regexSwift = [NSRegularExpression regularExpressionWithPattern:@"\"[^\"]*[\u4E00-\u9FA5]+[^\"\n]*?\"" options:NSRegularExpressionCaseInsensitive error:&error];
    if (error) {
        NSLog(@"Could't create regex with given string and options");
    }

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:_projectPath];
    NSString *filePath = nil;
    while ((filePath = [enumerator nextObject]) != nil) {
        // 要查找的后缀名
        NSString *suffix = [filePath pathExtension];
        if (suffix.length > 0) {
            suffix = [@"." stringByAppendingString:suffix];
        }
        if ([_suffixSet containsObject:suffix]) {
            filePath = [_projectPath stringByAppendingString:filePath];

            NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];

            NSArray *matches = [regex matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];
            if ([suffix isEqualToString:@".swift"]) {
                matches = [regexSwift matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];
            }
            NSString *relplacedString = content;

            for (int n = 0; n < matches.count; n++) {
                NSTextCheckingResult *obj = matches[n];

                NSString *china = [content substringWithRange:obj.range];

                NSRange range = [relplacedString rangeOfString:china];

                NSString *value = china;
                if (![suffix isEqualToString:@".swift"]) {
                    value = [china substringFromIndex:1];
                }
                NSString *key = [_valueKey objectForKey:value];
                if (key) {
                    NSString *loclizedStr = [NSString stringWithFormat:@"NSLocalizedString(@\"%@\", @\"\")", key];
                    if ([suffix containsString:@".swift"]) {
                        loclizedStr = [NSString stringWithFormat:@"NSLocalizedString(\"%@\", \"\")", key];
                    }
                    relplacedString = [relplacedString stringByReplacingOccurrencesOfString:china withString:loclizedStr options:NSLiteralSearch range:range];

                    if (n == matches.count - 1) {
                        NSError *error;
                        if (![relplacedString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
                        }
                    }
                }
            }
        }
    }
    [self startReadTofile];
}

@end
