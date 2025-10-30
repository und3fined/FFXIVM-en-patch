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

void clonePaks() {
  NSDictionary* pakMappings = @{
    @"pakchunk2940229633408208060-IOS.pak": @"1.0.2.100_IOS_100_P.pak", // - en
    @"pakchunk10659892668498200322-IOS.pak": @"1.0.2.101_IOS_101_P.pak", // - ja
    @"pakchunk16339885002121654293-IOS.pak": @"1.0.2.102_IOS_102_P.pak", // - ko
    @"pakchunk5684119864890796017-IOS.pak": @"1.0.2.103_IOS_103_P.pak", // - fr
    @"pakchunk17175032424564738712-IOS.pak": @"1.0.2.104_IOS_104_P.pak" // - de
  };

  NSFileManager *fileManager = [NSFileManager defaultManager];

  NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
  NSString *documentsDirectory = [documentsURL path];
  NSString *basePath = [documentsDirectory stringByAppendingPathComponent:@"FGame/Saved/Downloader/1.0.2.0/Dolphin/Paks"];

  NSString *InstalledPath = [[NSBundle mainBundle] bundlePath];
  NSString *CookedPath = [InstalledPath stringByAppendingPathComponent:@"cookeddata/fgame/content/paks"];

  // check exit basePath if not then exit wait for next open
  BOOL isDirectory = NO;
  if (![fileManager fileExistsAtPath:basePath isDirectory:&isDirectory] || !isDirectory) {
    NSLog(@"FFXIVM Paks directory does not exist at %@, skipping pak cloning.", basePath);
    return;
  }

  // Iterate over the pak mappings and clone files
  [pakMappings enumerateKeysAndObjectsUsingBlock:^(NSString *sourceFileName, NSString *destinationFileName, BOOL *stop) {
    NSString *sourcePath = [CookedPath stringByAppendingPathComponent:sourceFileName];
    NSString *destinationPath = [basePath stringByAppendingPathComponent:destinationFileName];

    NSString *standardizedSourcePath = [sourcePath stringByStandardizingPath];
    NSString *standardizedDestinationPath = [destinationPath stringByStandardizingPath];

    NSLog(@"FFXIVM Cloning from %@ to %@", standardizedSourcePath, standardizedDestinationPath);

    if ([fileManager fileExistsAtPath:standardizedSourcePath]) {
      NSError *copyError = nil;
      // Remove existing file at destination if it exists
      if ([fileManager fileExistsAtPath:standardizedDestinationPath]) {
        [fileManager removeItemAtPath:standardizedDestinationPath error:nil];
      }
      BOOL success = [fileManager copyItemAtPath:standardizedSourcePath toPath:standardizedDestinationPath error:&copyError];

      if (success) {
        NSLog(@"FFXIVM Successfully cloned %@ to %@", sourceFileName, destinationFileName);
      } else {
        NSLog(@"FFXIVM Error cloning %@ to %@: %@", sourceFileName, destinationFileName, copyError.localizedDescription);
      }
    } else {
      NSLog(@"FFXIVM Source file %@ does not exist, skipping.", sourceFileName);
    }
  }];
}

%ctor {
  NSLog(@"FFXIVM Initializing...");

  // Initialize core functionality
  writeGameUserSettingsToIni();
  NSLog(@"FFXIVM GameUserSettings.ini written to Documents directory.");

  // Clone special PAK files for i10n
  clonePaks();
  NSLog(@"FFXIVM PAK cloning process completed.");
}
