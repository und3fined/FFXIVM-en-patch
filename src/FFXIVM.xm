#import "FFXIVM.h"

void writeGameUserSettingsToIni() {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *defaultContent = @"[Internationalization]\nCulture=en";

  NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
  NSString *documentsDirectory = [documentsURL path];
  NSString *configPath = [documentsDirectory stringByAppendingPathComponent:@"FGame/Saved/Config/IOS"];

  NSLog(@"FFXIVM validate %@", configPath);

  BOOL isDirectory = NO;
  if (![fileManager fileExistsAtPath:configPath isDirectory:&isDirectory] || !isDirectory) {
    NSError *dirError = nil;
    [fileManager createDirectoryAtPath:configPath withIntermediateDirectories:YES attributes:nil error:&dirError];
    if (dirError) {
      NSLog(@"FFXIVM Error creating directory: %@", dirError.localizedDescription);
    }
  }

  NSString *userSettingsPath = [configPath stringByAppendingPathComponent:@"GameUserSettings.ini"];
  NSString *filePath = [userSettingsPath stringByStandardizingPath];

  // Check if the file exists, if not, create it
  if (![fileManager fileExistsAtPath:filePath]) {
    NSError *createError = nil;
    [defaultContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&createError];
    if (createError) {
      NSLog(@"Error creating file: %@", createError.localizedDescription);
    }
    NSLog(@"FFXIVM Created GameUserSettings.ini at %@", filePath);
  } else {
    NSError *error = nil;
    NSString *existingContent = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    if (existingContent) {
      NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^Culture=.*$" options:NSRegularExpressionAnchorsMatchLines error:nil];
      NSString *modifiedContent = [regex stringByReplacingMatchesInString:existingContent options:0 range:NSMakeRange(0, [existingContent length]) withTemplate:@"Culture=en"];
      if (![modifiedContent isEqualToString:existingContent]) {
        [modifiedContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
      }
    } else {
      [defaultContent writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
      if (error) {
        NSLog(@"Error writing to file: %@", error.localizedDescription);
      }
    }
  }
}

%ctor {
  NSLog(@"FFXIVM Initializing...");
  writeGameUserSettingsToIni();
  NSLog(@"FFXIVM GameUserSettings.ini written to Documents directory.");
}
