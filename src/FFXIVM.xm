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

void removeFilePak() {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
  NSString *documentsDirectory = [documentsURL path];
  NSString *basePath = [documentsDirectory stringByAppendingPathComponent:@"FGame/Saved/Downloader/1.0.2.0/Dolphin/Paks"];
  
  // Array of files to remove
  NSArray *filesToRemove = @[
    @"1.0.2.12_IOS_12_P.pak",
    @"1.0.2.12_sf_metal.0.metallib",
    @"1.0.2.12_sf_metal.metalmap"
  ];
  
  for (NSString *fileName in filesToRemove) {
    NSString *filePath = [basePath stringByAppendingPathComponent:fileName];
    NSString *standardizedPath = [filePath stringByStandardizingPath];
    
    NSLog(@"FFXIVM Checking for %@ at %@", fileName, standardizedPath);
    
    if ([fileManager fileExistsAtPath:standardizedPath]) {
      NSError *removeError = nil;
      BOOL success = [fileManager removeItemAtPath:standardizedPath error:&removeError];
      
      if (success) {
        NSLog(@"FFXIVM Successfully removed %@", fileName);
      } else {
        NSLog(@"FFXIVM Error removing %@: %@", fileName, removeError.localizedDescription);
      }
    } else {
      NSLog(@"FFXIVM %@ not found, skipping removal", fileName);
    }
  }
}

%ctor {
  NSLog(@"FFXIVM Initializing...");
  writeGameUserSettingsToIni();
  removeFilePak();
  NSLog(@"FFXIVM GameUserSettings.ini written to Documents directory.");
}
