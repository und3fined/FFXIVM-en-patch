#import "DialogueFix.h"
#import "FileMonitoring.h"

// Helper function to write to log file in Documents directory
void writeToLogFile(NSString *message) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
  NSString *documentsDirectory = [documentsURL path];
  NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"FFXIVM.log"];

  // Timestamp
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
  NSString *timestamp = [formatter stringFromDate:[NSDate date]];
  NSString *logMessage = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];

  // Append to file
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
  if (fileHandle) {
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[logMessage dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
  } else {
    [logMessage writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
  }
}

// Dialogues were broken with 1.0.2.12
void dialogueFix() {
  NSFileManager *fileManager = [NSFileManager defaultManager];

  NSURL *documentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
  NSString *documentsDirectory = [documentsURL path];

  // Define source and destination paths for the bundle
  // For sideloaded apps, look in the main app bundle first, then fallback to system path
  NSString *bundlePath = nil;
  NSBundle *bundle = nil;
  
  // Try to find the bundle in the main app bundle (for sideloaded apps)
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *mainBundlePath = [mainBundle pathForResource:@"FFXIVMBundle" ofType:@"bundle"];
  if (mainBundlePath) {
    bundlePath = mainBundlePath;
    bundle = [NSBundle bundleWithPath:bundlePath];
    writeToLogFile([NSString stringWithFormat:@"[INFO] Found bundle in main app bundle: %@", bundlePath]);
  } else {
    // Fallback to system path (for jailbroken devices)
    bundlePath = @"/Library/Application Support/FFXIVM-en-patch/FFXIVMBundle.bundle";
    bundle = [NSBundle bundleWithPath:bundlePath];
    if (!bundle) {
      // Try the old path as final fallback
      bundlePath = @"/Library/MobileSubstrate/DynamicLibraries/FFXIVMBundle.bundle";
      bundle = [NSBundle bundleWithPath:bundlePath];
    }
    writeToLogFile([NSString stringWithFormat:@"[INFO] Using system bundle path: %@", bundlePath]);
  }

  if (!bundle) {
    writeToLogFile([NSString stringWithFormat:@"[ERROR] Failed to create bundle from path: %@", bundlePath]);
    return;
  }

  // For system bundles (jailbroken), try to load. For app bundles (sideloaded), just use directly
  if (!mainBundlePath && ![bundle load]) {
    writeToLogFile([NSString stringWithFormat:@"[ERROR] Failed to load FFXIVM bundle from %@", bundlePath]);
    return;
  }

  // Retrieve the database file path from the bundle
  NSString *databasePath = [bundle pathForResource:@"FDataBaseLoc" ofType:@"db"];
  if (!databasePath || ![fileManager fileExistsAtPath:databasePath]) {
    writeToLogFile(@"[ERROR] FFXIVM Database file not found in bundle Resources");
    return;
  }

  // Prepare the destination path inside the app's FGame directory
  NSString *dbDestinationDir = [documentsDirectory stringByAppendingPathComponent:@"FGame/PersistentDownloadDir/Database"];
  BOOL isDirectory = NO;
  if (![fileManager fileExistsAtPath:dbDestinationDir isDirectory:&isDirectory] || !isDirectory) {
    NSError *dirError = nil;
    [fileManager createDirectoryAtPath:dbDestinationDir withIntermediateDirectories:YES attributes:nil error:&dirError];
    if (dirError) {
      writeToLogFile([NSString stringWithFormat:@"[ERROR] Failed to create database directory: %@", dirError.localizedDescription]);
      return;
    }
    writeToLogFile([NSString stringWithFormat:@"[INFO] Created database directory: %@", dbDestinationDir]);
  }

  // Final destination file 
  NSString *destFilePath = [dbDestinationDir stringByAppendingPathComponent:@"FDataBaseLoc.db"];
  writeToLogFile([NSString stringWithFormat:@"[INFO] Copying database from %@ to %@", databasePath, destFilePath]);

  // Use a more robust file replacement approach
  NSError *replacementError = nil;
  BOOL fileExists = [fileManager fileExistsAtPath:destFilePath];
  
  if (fileExists) {
    writeToLogFile([NSString stringWithFormat:@"[INFO] Existing database found, replacing: %@", destFilePath]);
    
    // Try to use replaceItemAtURL for atomic replacement (iOS 4.0+)
    NSURL *sourceURL = [NSURL fileURLWithPath:databasePath];
    NSURL *destURL = [NSURL fileURLWithPath:destFilePath];
    
    NSURL *resultingURL = nil;
    if ([fileManager replaceItemAtURL:destURL withItemAtURL:sourceURL backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:&resultingURL error:&replacementError]) {
      writeToLogFile(@"[INFO] Successfully replaced existing database using atomic replacement");
      
      // Setup file monitoring
      setupFileMonitoring(databasePath, destFilePath);
    } else {
      writeToLogFile([NSString stringWithFormat:@"[WARN] Atomic replacement failed: %@, trying manual replacement", replacementError.localizedDescription]);
      
      // Fallback to manual remove and copy
      if ([fileManager removeItemAtPath:destFilePath error:&replacementError]) {
        writeToLogFile(@"[INFO] Successfully removed existing database");
        
        // Now copy the new file
        if ([fileManager copyItemAtPath:databasePath toPath:destFilePath error:&replacementError]) {
          writeToLogFile(@"[INFO] Successfully copied new database after manual removal");
          
          // Setup file monitoring
          setupFileMonitoring(databasePath, destFilePath);
        } else {
          writeToLogFile([NSString stringWithFormat:@"[ERROR] Failed to copy database after removal: %@", replacementError.localizedDescription]);
        }
      } else {
        writeToLogFile([NSString stringWithFormat:@"[ERROR] Failed to remove existing database: %@", replacementError.localizedDescription]);
      }
    }
  } else {
    writeToLogFile(@"[INFO] No existing database found, creating new one");
    
    // No existing file, just copy
    if ([fileManager copyItemAtPath:databasePath toPath:destFilePath error:&replacementError]) {
      writeToLogFile(@"[INFO] Successfully copied new database");
      
      // Setup file monitoring
      setupFileMonitoring(databasePath, destFilePath);
    } else {
      writeToLogFile([NSString stringWithFormat:@"[ERROR] Failed to copy database: %@", replacementError.localizedDescription]);
    }
  }
} 