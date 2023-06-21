//
//  ViewController.m
//  ConvertApp
//
//  Created by zhongqing on 2019/9/27.
//  Copyright © 2019 ZQing. All rights reserved.
//

#import "ViewController.h"

#define LocalizedStringPreffix   @"NSLocalizedString("

@interface ViewController () <NSTableViewDataSource, NSTableViewDelegate>{

}

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
@property (weak) IBOutlet NSButton *ClearBtn;

@property (nonatomic, copy) NSString *projectPath;
@property (nonatomic, copy) NSString *exportPath;
@property (nonatomic, strong) NSMutableSet *suffixSet;          //要遍历的后缀文件名
@property (nonatomic, strong) NSMutableDictionary *keyValue;    //key - value
@property (nonatomic, strong) NSMutableArray *keyAry;           //
@property (nonatomic, strong) NSMutableDictionary *valueKey;    //value -  key(英文value 和key 都保持唯一)
@property (nonatomic, strong) NSMutableDictionary *oldValueKey; //value -key
@property (nonatomic, copy) NSArray *ignoreFolder;
@property (nonatomic, strong) NSRegularExpression *regex;
@property (nonatomic, strong) NSRegularExpression *regex_Aite;

///新加入的中文
@property (nonatomic, strong) NSMutableDictionary  *newtextDict;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    if([[NSUserDefaults standardUserDefaults] objectForKey:@"Project_Path"]){
        _projectPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"Project_Path"];
        [self.textField setStringValue:_projectPath];
    }
    if([[NSUserDefaults standardUserDefaults] objectForKey:@"Export_Path"]){
        _exportPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"Export_Path"];
        [self.exportField setStringValue:_exportPath];
    }
    
    _suffixSet = [NSMutableSet set];

    _keyValue = [NSMutableDictionary dictionary];
    _valueKey = [NSMutableDictionary dictionary];
    _oldValueKey = [NSMutableDictionary dictionary];
    _newtextDict = [NSMutableDictionary dictionary];

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
    return _keyValue.count;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    if (_keyAry.count > row) {
        NSString *key = _keyAry[row];
       // resultIndex
        if ([tableColumn.identifier isEqualToString:@"resultIndex"]) {
            return [NSString stringWithFormat:@"%ld",(long)row + 1];
        }
        else if ([tableColumn.identifier isEqualToString:@"resultkey"]) {
            return key;
        } else if ([tableColumn.identifier isEqualToString:@"resultvalue"]) {
            return [_keyValue objectForKey:key];
        }
    }
    return @"";
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)seletRootFolder:(NSButton *)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];

    NSWindow *window = [[NSApplication sharedApplication] keyWindow];
   
    __weak __typeof(self) weakSelf = self;
    [openPanel beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == 1) {
            NSURL *fileUrl = [[openPanel URLs] objectAtIndex:0];
            NSString *filePath = [[fileUrl.absoluteString componentsSeparatedByString:@"file://"] lastObject];
            NSString *decodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault, (CFStringRef)filePath, CFSTR("")));
            weakSelf.projectPath = decodedString;
            [weakSelf.textField setStringValue:decodedString];
            
            [[NSUserDefaults standardUserDefaults] setValue:decodedString forKey:@"Project_Path"];
        }}
    ];
}

- (IBAction)startSearch:(id)sender {

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

    [_keyValue removeAllObjects];
    [_valueKey removeAllObjects];
    [_keyAry removeAllObjects];

//    NSString *defaultKey = [self localizedKey];
    while ((filePath = [enumerator nextObject]) != nil) {
        // 要查找的后缀名
        NSString *suffix = [filePath pathExtension];

        if (suffix.length > 0) {
            suffix = [@"." stringByAppendingString:suffix];
        }
        if ([_suffixSet containsObject:suffix]) {
            NSArray *ary = [ignoreExp matchesInString:filePath options:NSMatchingReportCompletion range:NSMakeRange(0, filePath.length)];
            if (ary.count > 0) {
                NSLog(@"ignor filePath:%@",filePath);
                continue;
            }

            filePath = [_projectPath stringByAppendingString:filePath];
            NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];

            NSArray *matches = [self.regex_Aite matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];
            if ([suffix isEqualToString:@".swift"]) {
                matches = [self.regex matchesInString:content options:NSMatchingReportCompletion range:NSMakeRange(0, content.length)];
            }
            if (matches.count <= 0){
                continue;
            }
            
            for (int n = 0; n < matches.count; n++) {
                NSTextCheckingResult *obj = matches[n];

                NSString *china = [content substringWithRange:obj.range];

                [_keyValue setValue:china forKey:china];
                
            }
        }
    }

    if (_keyValue.count == 0) {
        [self showAlert:@"工程中没有中文"];
        [self.resultTable reloadData];
        return;
    }
    _keyAry = [_keyValue.allKeys mutableCopy];

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

    NSRegularExpression *ignorRex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"%@/", ss] options:NSRegularExpressionCaseInsensitive error:&error];
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
    NSString *defaultKey = @"XHLocalizedKey";
    if (self.localizedkeyField.stringValue.length > 0) {
        defaultKey = self.localizedkeyField.stringValue;
    }
    return defaultKey;
}

#pragma - mark privateMethods
- (void)startReadTofile {
    if(_newtextDict.count <= 0){
        [self showAlert:@"没有可插入的中文"];
        return;
    }
    __block NSString *willRead = @"";
    if ([[NSFileManager defaultManager] fileExistsAtPath:_exportPath]) {
        willRead = [NSString stringWithContentsOfFile:_exportPath encoding:NSUTF8StringEncoding error:nil];

        NSDateFormatter *fomart = [[NSDateFormatter alloc] init];
        [fomart setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString *time = [fomart stringFromDate:[NSDate date]];

        NSString *flagString = [NSString stringWithFormat:@"// Begin Insert At %@ \n\n", time];
        willRead = [willRead stringByAppendingString:flagString];
    }

    [_newtextDict enumerateKeysAndObjectsUsingBlock:^(NSString * key, NSString* obj, BOOL * _Nonnull stop) {
        if([key hasPrefix:@"@"]){
            key = [key substringFromIndex:1];
        }
        if([obj hasPrefix:@"@"]){
            obj = [obj substringFromIndex:1];
        }
        willRead = [willRead stringByAppendingFormat:@"%@ = %@;\n",key,obj];
    }];
    
    BOOL isSuccess = [[NSFileManager defaultManager] createFileAtPath:_exportPath contents:[willRead dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];

    if (isSuccess) {
        [self showAlert:@"Success"];
    } else {
        [self showAlert:@"导出文件失败"];
    }
}

- (NSMutableDictionary *)readExistLocalizedString {
    //[_oldValueKey removeAllObjects];

    NSMutableDictionary *dict = @{}.mutableCopy;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *tmpFile = [_exportField stringValue];
    if (!tmpFile) {
        [self showAlert:@"请输入导出路径"];
        return dict;
    }
    
    if ([fileManager fileExistsAtPath:tmpFile]) {
        NSString *content = [NSString stringWithContentsOfFile:tmpFile encoding:NSUTF8StringEncoding error:nil];
        NSArray *array = [content componentsSeparatedByString:@"\n"];
        for (int n = 0 ; n < array.count; n++){
            NSString *string = [array[n] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if([string hasPrefix:@"//"] || ![string hasSuffix:@";"]){
                continue;
            }
            NSArray *keyvalue = [string componentsSeparatedByString:@"="];
            if(keyvalue.count == 2){
                NSString *key = [keyvalue[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *value = [keyvalue[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                [dict setValue:value forKey:key];
            }
        }
    }
    return dict;
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
    [openPanel beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == 1) {
            NSURL *fileUrl = [[openPanel URLs] objectAtIndex:0];
            NSString *filePath = [[fileUrl.absoluteString componentsSeparatedByString:@"file://"] lastObject];
            NSString *decodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault, (CFStringRef)filePath, CFSTR("")));
            NSString *exportPath = [decodedString stringByAppendingPathComponent:@"Localizable.strings"];
            [weakSelf.exportField setStringValue:exportPath];
            
            weakSelf.exportPath = exportPath;
            [[NSUserDefaults standardUserDefaults] setValue:exportPath forKey:@"Export_Path"];
        }
    }];
}

- (IBAction)startExport:(id)sender {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (_exportPath == nil || _exportPath.length < 0) {
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

    ///通过路径找出已经本地话过的文件内容
    _oldValueKey = [self readExistLocalizedString];
    ///通过跟本地Localizable.strings文件比较。找出新插入的中文；
    if (_oldValueKey.count > 0){
        [_keyValue enumerateKeysAndObjectsUsingBlock:^(NSString * key, NSString * value, BOOL * _Nonnull stop) {
            if([value hasPrefix:@"@"]){
                value = [value substringFromIndex:1];
            }
            if(![_oldValueKey objectForKey:value]){
                [_newtextDict setValue:value forKey:key];
            }
        }];
    }else{
        [_newtextDict addEntriesFromDictionary:_keyValue];
    }
    ///合并所有的列表
    [_keyValue addEntriesFromDictionary:_oldValueKey];

    ///
    [_valueKey removeAllObjects];
    [_keyValue enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSLog(@"%@ == %@ \n",key,obj);
        [_valueKey setValue:key forKey:obj];
    }];

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
            if(matches.count <= 0){
                continue;
            }
            NSString *relplacedString = content;

            NSInteger index = 0;
            BOOL isReplace = NO;  //是否要替换
            for (int n = 0; n < matches.count; n++) {
                NSTextCheckingResult *obj = matches[n];
                ///从原始文本找到
                NSString *china = [content substringWithRange:obj.range];
            
                NSString *tmp = [relplacedString substringFromIndex:index];
                
                NSRange range = [tmp rangeOfString:china];
                
                range = NSMakeRange(range.location + index, range.length);
             
                //NSRange range = [relplacedString rangeOfString:china];
            

                if(range.location > LocalizedStringPreffix.length){
                    NSRange tmpRange = NSMakeRange(range.location - LocalizedStringPreffix.length, LocalizedStringPreffix.length);

                    NSString *tmpStr = [relplacedString substringWithRange:tmpRange];

                    if([tmpStr isEqualToString:LocalizedStringPreffix]){
                        if (n == matches.count - 1 && isReplace) {
                            [self beginReplaceString:relplacedString path:filePath];
                        }
                        index = range.location + range.length;
                        continue;
                    }
                }

                NSString *value = china;
                //找出对应的key
                NSString *key = [_valueKey objectForKey:value];

                if (key) {
                    isReplace = YES;
                    NSString *loclizedStr = [LocalizedStringPreffix stringByAppendingFormat:@"%@,@\"\")",key];
                    if ([suffix containsString:@".swift"]) {
                        loclizedStr = [LocalizedStringPreffix stringByAppendingFormat:@"%@,@\"\")",key];
                    }
                    relplacedString = [relplacedString stringByReplacingOccurrencesOfString:china withString:loclizedStr options:NSLiteralSearch range:range];
                    
                    index = range.location + loclizedStr.length;
                }
                
                if (n == matches.count - 1 && isReplace) {
                    [self beginReplaceString:relplacedString path:filePath];
                }
            }
        }
    }
    [self startReadTofile];
}

- (void)beginReplaceString:(NSString *)relplacedString path:(NSString *)filePath{
    NSError *error;
    if (![relplacedString writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSLog(@"write error :%@",filePath);
    }
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
