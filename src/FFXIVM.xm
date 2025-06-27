#import "FFXIVM.h"

- (NSURL *)applicationDocumentsDirectory {
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

void writeGameUserSettingsToIni() {
  NSURL *documentsURL = [[FFXIVM new] applicationDocumentsDirectory];
  NSString *documentsDirectory = [documentsURL path];
  NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"FGame/Saved/Config/IOS/GameUserSettings.ini"];

  NSLog(@"[FFXIVM-en-patch] Writing GameUserSettings.ini to %@", filePath);

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
  NSLog(@"[FFXIVM-en-patch] Initializing...");
  writeGameUserSettingsToIni();
  NSLog(@"[FFXIVM-en-patch] GameUserSettings.ini written to Documents directory.");
}
