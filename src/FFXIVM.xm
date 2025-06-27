#import "FFXIVM.h"

void writeGameUserSettingsToIni() {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths firstObject];
  NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"FGame/Saved/Config/IOS/GameUserSettings.ini"];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:filePath]) {
    [fileManager createFileAtPath:filePath contents:nil attributes:nil];
  }

  NSError *error = nil;
  NSString *existingContent = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
  if (existingContent) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^Culture=.*$" options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSString *modifiedContent = [regex stringByReplacingMatchesInString:existingContent options:0 range:NSMakeRange(0, [existingContent length]) withTemplate:@"Culture=en"];
    if (![modifiedContent isEqualToString:existingContent]) {
      [modifiedContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
  } else {
    NSString *content = @"[Internationalization]\nCulture=en";
    [content writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
      NSLog(@"Error writing to file: %@", error.localizedDescription);
    }
  }
}

%ctor {
  writeGameUserSettingsToIni();
  NSLog(@"FFXIVM: GameUserSettings.ini written to Documents directory.");
}
