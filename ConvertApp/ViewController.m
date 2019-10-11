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
@property (weak) IBOutlet NSTextField *localizedkeyField;

@property (nonatomic, copy) NSString *projectPath;
@property (nonatomic, strong) NSMutableSet *suffixSet;          //要遍历的后缀文件名
@property (nonatomic, strong) NSMutableDictionary *keyValue;    //key - value
@property (nonatomic, strong) NSMutableArray *keyAry;           //
@property (nonatomic, strong) NSMutableDictionary *valueKey;    //value -  key(英文value 和key 都保持唯一)
@property (nonatomic, strong) NSMutableDictionary *oldValueKey; //value -key
@property (nonatomic, copy) NSArray *ignoreFolder;
@property (nonatomic, strong) NSRegularExpression *regex;
@property (nonatomic, strong) NSRegularExpression *regex_Aite;
@property (weak) IBOutlet NSButton *ClearBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _suffixSet = [NSMutableSet set];

    _keyValue = [NSMutableDictionary dictionary];
    _valueKey = [NSMutableDictionary dictionary];
    _oldValueKey = [NSMutableDictionary dictionary];

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

#pragma - mark NSTableViewDataSource &&NSTableViewDelegate
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
                            NSString *exportPath = [decodedString stringByAppendingPathComponent:@"Localizable.strings"];
                            [weakSelf.exportField setStringValue:exportPath];
                        }
                      }];
}

- (IBAction)startSearch:(id)sender {
    NSLog(@"seletRootFolder");
    _localizedkeyField.enabled = NO;
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

    NSRegularExpression *ignoreExp = [self ignorExp:_ignoreFolder];
    //.h .swift
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:_projectPath];
    NSString *filePath = nil;
    NSMutableSet *set = [[NSMutableSet alloc] init];
    NSMutableArray *chinaAry = [NSMutableArray array];
    [_keyValue removeAllObjects];
    [_valueKey removeAllObjects];
    [_keyAry removeAllObjects];

    NSString *defaultKey = [self localizedKey];
    while ((filePath = [enumerator nextObject]) != nil) {
        // 要查找的后缀名
        NSString *suffix = [filePath pathExtension];

        if (suffix.length > 0) {
            suffix = [@"." stringByAppendingString:suffix];
        }
        if ([_suffixSet containsObject:suffix]) {
            NSArray *ary = [ignoreExp matchesInString:filePath options:NSMatchingReportCompletion range:NSMakeRange(0, filePath.length)];
            if (ary.count > 0) {
                continue;
            }

            filePath = [_projectPath stringByAppendingString:filePath];
            NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];

            NSArray *matches = [self.regex_Aite matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];
            if ([suffix isEqualToString:@".swift"]) {
                matches = [self.regex matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];
            }

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

                    NSString *key = [NSString stringWithFormat:@"%@%lu", defaultKey, (unsigned long)nIndex];

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
    self.exportDir.enabled = NO;
    self.ClearBtn.enabled = YES;
    self.exportBtn.enabled = YES;
}

- (NSRegularExpression *)ignorExp:(NSArray *)ignoreAry {
    if (ignoreAry.count == 0) {
        return nil;
    }
    NSError *error = nil;
    NSString *ss = [ignoreAry componentsJoinedByString:@"|"];

    NSRegularExpression *ignorRex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^(%@)/", ss] options:NSRegularExpressionCaseInsensitive error:&error];
    if (error) {
        [self showAlert:error.localizedDescription];
    }
    return ignorRex;
}

#pragma - mark lazyload
- (NSRegularExpression *)regex {
    if (!_regex) {
        NSString *pattern = @"\"[^\"]*[\u4E00-\u9FA5]+[^\"\n]*?\"";
        NSError *error = nil;
        _regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
        if (error) {
            NSLog(@"Could't create regex with given string and options");
        }
    }
    return _regex;
}

- (NSRegularExpression *)regex_Aite {
    if (!_regex_Aite) {
        NSString *pattern = @"@\"[^\"]*[\u4E00-\u9FA5]+[^\"\n]*?\"";
        NSError *error = nil;
        _regex_Aite = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
        if (error) {
            NSLog(@"Could't create regex with given string and options");
        }
    }
    return _regex_Aite;
}

- (NSString *)localizedKey {
    NSString *defaultKey = @"LocalizedKey";
    if (self.localizedkeyField.stringValue.length > 0) {
        defaultKey = self.localizedkeyField.stringValue;
    }
    return defaultKey;
}

#pragma - mark privateMethods
- (void)startReadTofile {
    NSString *tmpFile = [_exportField stringValue];

    NSString *willRead = @"";
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpFile]) {
        willRead = [NSString stringWithContentsOfFile:tmpFile encoding:NSUTF8StringEncoding error:nil];

        NSDateFormatter *fomart = [[NSDateFormatter alloc] init];
        [fomart setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString *time = [fomart stringFromDate:[NSDate date]];

        NSString *flagString = [NSString stringWithFormat:@"// Begin Insert At %@ \n\n", time];
        willRead = [willRead stringByAppendingString:flagString];
    }

    NSString *defaultKey = [self localizedKey];
    for (int n = 0; n < _keyValue.count; n++) {
        NSString *key = [defaultKey stringByAppendingFormat:@"%d", n];
        NSString *value = [_keyValue objectForKey:key];

        if ([value hasPrefix:@"@"]) {
            value = [value substringFromIndex:1];
        }
        if (_oldValueKey.count > 0) {
            if ([_oldValueKey objectForKey:value]) {
                continue;
            }
        }
        willRead = [willRead stringByAppendingFormat:@"\"%@\"   =  %@;\n", key, value];
    }
    BOOL isSuccess = [[NSFileManager defaultManager] createFileAtPath:tmpFile contents:[willRead dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];

    if (isSuccess) {
        [self showAlert:@"Success"];
    } else {
        [self showAlert:@"导出文件失败"];
    }
}

- (void)readExistLocalizedString {
    [_oldValueKey removeAllObjects];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *tmpFile = [_exportField stringValue];
    if (!tmpFile) {
        [self showAlert:@"请输入导出路径"];
        return;
    }

    if ([fileManager fileExistsAtPath:tmpFile]) {
        NSString *content = [NSString stringWithContentsOfFile:tmpFile encoding:NSUTF8StringEncoding error:nil];

        NSString *pattern = @"\"\\w+\"\\s+=\\s+.+\n";
        NSError *error = nil;
        NSRegularExpression *exp = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
        if (error) {
            NSLog(@"Could't create regex with given string and options");
        }
        NSArray *matches = [exp matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];
        for (NSTextCheckingResult *result in matches) {
            NSString *lineStr = [content substringWithRange:result.range];
            if ([lineStr containsString:@"//"]) {
                continue;
            }
            NSRange range = [lineStr rangeOfString:@"="];
            if (range.location != NSNotFound) {
                NSString *key = [[lineStr substringToIndex:range.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                key = [key stringByReplacingOccurrencesOfString:@"\"" withString:@""];

                NSString *value = [[lineStr substringFromIndex:range.location + range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (![value hasSuffix:@";"]) {
                    continue;
                }
                value = [value substringWithRange:NSMakeRange(0, value.length - 1)];

                [_oldValueKey setValue:key forKey:value];
            }
        }
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

#pragma - mark ClickMetods
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

//导出目录
- (IBAction)clickExportButton:(id)sender {
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
                            NSString *exportPath = [decodedString stringByAppendingPathComponent:@"Localizable.strings"];
                            [weakSelf.exportField setStringValue:exportPath];
                        }
                      }];
}

- (IBAction)startExport:(id)sender {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *tmpFile = [_exportField stringValue];
    if (!tmpFile) {
        [self showAlert:@"请输入导出路径"];
        return;
    }

    if (_projectPath.length <= 0) {
        [self showAlert:@"请选择项目工程地址"];
        return;
    }

    if (_suffixSet.count == 0) {
        [self showAlert:@"请选择要查找文件的后缀名"];
        return;
    }

    //通过路径找出已经本地话过的文件内容
    [self readExistLocalizedString];

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

            NSArray *matches = [self.regex_Aite matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];
            if ([suffix isEqualToString:@".swift"]) {
                matches = [self.regex matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];
            }
            NSString *relplacedString = content;

            for (int n = 0; n < matches.count; n++) {
                NSTextCheckingResult *obj = matches[n];

                NSString *china = [content substringWithRange:obj.range];

                NSRange range = [relplacedString rangeOfString:china];

                NSString *value = china;
                //找出对应的key
                NSString *key = [_valueKey objectForKey:value];
                //如果就的配置文件有值，改用旧的
                if (_oldValueKey.count > 0) {
                    if ([value hasPrefix:@"@"]) {
                        value = [value substringFromIndex:1];
                    }
                    if ([_oldValueKey objectForKey:value]) {
                        key = [_oldValueKey objectForKey:value];
                    }
                }
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
- (IBAction)clickClearBtn:(id)sender {
    self.localizedkeyField.enabled = YES;
    self.exportDir.enabled = YES;
    
    [self.keyAry removeAllObjects];
    [self.keyValue removeAllObjects];
    [self.valueKey removeAllObjects];
    [self.resultTable reloadData];
}

- (void)textDidEndEditing:(NSNotification *)notification
{
    NSLog(@"textDidEndEditing");
}

- (void)textDidChange:(NSNotification *)notification
{
    NSLog(@"textDidChange");
}

@end
