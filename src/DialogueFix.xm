#import "DialogueFix.h"
#import "FileMonitoring.h"
#import <sys/stat.h>
#import <sys/attr.h>
#import <errno.h>

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

// Helper function to set file permissions to read-only
BOOL setFileReadOnly(NSString *filePath) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  if (![fileManager fileExistsAtPath:filePath]) {
    writeToLogFile([NSString stringWithFormat:@"[PERM] File does not exist: %@", filePath]);
    return NO;
  }
  
  NSError *error = nil;
  NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:&error];
  if (error) {
    writeToLogFile([NSString stringWithFormat:@"[PERM] Failed to get file attributes: %@", error.localizedDescription]);
    return NO;
  }
  
  // Get current permissions
  NSNumber *permissions = [attributes objectForKey:NSFilePosixPermissions];
  NSInteger currentPerms = [permissions integerValue];
  
  // Remove write permissions for owner, group, and others (0444)
  NSInteger readOnlyPerms = currentPerms & ~(S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH);
  readOnlyPerms |= S_IRUSR | S_IRGRP | S_IROTH; // Set read permissions for all
  
  // Set the new permissions
  NSDictionary *newAttributes = @{NSFilePosixPermissions: @(readOnlyPerms)};
  if ([fileManager setAttributes:newAttributes ofItemAtPath:filePath error:&error]) {
    writeToLogFile([NSString stringWithFormat:@"[PERM] Successfully set read-only permissions on: %@", filePath]);
    return YES;
  } else {
    writeToLogFile([NSString stringWithFormat:@"[PERM] Failed to set read-only permissions: %@", error.localizedDescription]);
    return NO;
  }
}

// Helper function to restore write permissions (for when we need to update the file)
BOOL restoreFileWritePermissions(NSString *filePath) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  if (![fileManager fileExistsAtPath:filePath]) {
    writeToLogFile([NSString stringWithFormat:@"[PERM] File does not exist: %@", filePath]);
    return NO;
  }
  
  NSError *error = nil;
  NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:&error];
  if (error) {
    writeToLogFile([NSString stringWithFormat:@"[PERM] Failed to get file attributes: %@", error.localizedDescription]);
    return NO;
  }
  
  // Get current permissions
  NSNumber *permissions = [attributes objectForKey:NSFilePosixPermissions];
  NSInteger currentPerms = [permissions integerValue];
  
  // Add write permissions for owner (0644)
  NSInteger writePerms = currentPerms | S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;
  
  // Set the new permissions
  NSDictionary *newAttributes = @{NSFilePosixPermissions: @(writePerms)};
  if ([fileManager setAttributes:newAttributes ofItemAtPath:filePath error:&error]) {
    writeToLogFile([NSString stringWithFormat:@"[PERM] Successfully restored write permissions on: %@", filePath]);
    return YES;
  } else {
    writeToLogFile([NSString stringWithFormat:@"[PERM] Failed to restore write permissions: %@", error.localizedDescription]);
    return NO;
  }
}

// Helper function to make file immutable (chattr +i equivalent)
BOOL setFileImmutable(NSString *filePath) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  if (![fileManager fileExistsAtPath:filePath]) {
    writeToLogFile([NSString stringWithFormat:@"[IMMUTABLE] File does not exist: %@", filePath]);
    return NO;
  }
  
  // Try to set the immutable flag using system call
  const char *path = [filePath UTF8String];
  int result = chflags(path, UF_IMMUTABLE);
  
  if (result == 0) {
    writeToLogFile([NSString stringWithFormat:@"[IMMUTABLE] Successfully set immutable flag on: %@", filePath]);
    return YES;
  } else {
    writeToLogFile([NSString stringWithFormat:@"[IMMUTABLE] Failed to set immutable flag: %s", strerror(errno)]);
    return NO;
  }
}

// Helper function to remove immutable flag
BOOL removeFileImmutable(NSString *filePath) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  if (![fileManager fileExistsAtPath:filePath]) {
    writeToLogFile([NSString stringWithFormat:@"[IMMUTABLE] File does not exist: %@", filePath]);
    return NO;
  }
  
  // Try to remove the immutable flag using system call
  const char *path = [filePath UTF8String];
  int result = chflags(path, 0);
  
  if (result == 0) {
    writeToLogFile([NSString stringWithFormat:@"[IMMUTABLE] Successfully removed immutable flag from: %@", filePath]);
    return YES;
  } else {
    writeToLogFile([NSString stringWithFormat:@"[IMMUTABLE] Failed to remove immutable flag: %s", strerror(errno)]);
    return NO;
  }
}

// Helper function to check if file is protected (immutable or read-only)
BOOL isFileProtected(NSString *filePath) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  if (![fileManager fileExistsAtPath:filePath]) {
    return NO;
  }
  
  NSError *error = nil;
  NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:&error];
  if (error) {
    return NO;
  }
  
  // Check for immutable flag
  NSNumber *flags = [attributes objectForKey:NSFileImmutable];
  if (flags && [flags boolValue]) {
    return YES;
  }
  
  // Check for read-only permissions
  NSNumber *permissions = [attributes objectForKey:NSFilePosixPermissions];
  if (permissions) {
    NSInteger perms = [permissions integerValue];
    // Check if write permissions are missing for owner
    if (!(perms & S_IWUSR)) {
      return YES;
    }
  }
  
  return NO;
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


  //also delete FDataBase.db if it exists

  NSString *fDataBasePath = [dbDestinationDir stringByAppendingPathComponent:@"FDataBase.db"];
  if ([fileManager fileExistsAtPath:fDataBasePath]) {
    NSError *deleteError = nil;
    if ([fileManager removeItemAtPath:fDataBasePath error:&deleteError]) {
      writeToLogFile(@"[INFO] Successfully deleted FDataBase.db on first run");
    } else {
      writeToLogFile([NSString stringWithFormat:@"[WARN] Failed to delete FDataBase.db: %@", deleteError.localizedDescription]);
    }
  } else {
    writeToLogFile(@"[INFO] FDataBase.db not found, skipping deletion");
  }

  // Use a more robust file replacement approach
  NSError *replacementError = nil;
  BOOL fileExists = [fileManager fileExistsAtPath:destFilePath];
  BOOL fileCopied = NO;
  
  if (fileExists) {
    writeToLogFile([NSString stringWithFormat:@"[INFO] Existing database found, replacing: %@", destFilePath]);
    
    // Try to use replaceItemAtURL for atomic replacement (iOS 4.0+)
    NSURL *sourceURL = [NSURL fileURLWithPath:databasePath];
    NSURL *destURL = [NSURL fileURLWithPath:destFilePath];
    
    NSURL *resultingURL = nil;
    if ([fileManager replaceItemAtURL:destURL withItemAtURL:sourceURL backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:&resultingURL error:&replacementError]) {
      writeToLogFile(@"[INFO] Successfully replaced existing database using atomic replacement");
      fileCopied = YES;
    } else {
      writeToLogFile([NSString stringWithFormat:@"[WARN] Atomic replacement failed: %@, trying manual replacement", replacementError.localizedDescription]);
      
      // Fallback to manual remove and copy
      if ([fileManager removeItemAtPath:destFilePath error:&replacementError]) {
        writeToLogFile(@"[INFO] Successfully removed existing database");
        
        // Now copy the new file
        if ([fileManager copyItemAtPath:databasePath toPath:destFilePath error:&replacementError]) {
          writeToLogFile(@"[INFO] Successfully copied new database after manual removal");
          fileCopied = YES;
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
      fileCopied = YES;
    } else {
      writeToLogFile([NSString stringWithFormat:@"[ERROR] Failed to copy database: %@", replacementError.localizedDescription]);
    }
  }
  
  // If file was successfully copied, set permissions to prevent overwriting
  if (fileCopied) {
    writeToLogFile(@"[INFO] Setting file permissions to prevent overwriting");
    
    // First try to set immutable flag (strongest protection)
    if (setFileImmutable(destFilePath)) {
      writeToLogFile(@"[INFO] Successfully set immutable flag on database file");
    } else {
      // Fallback to read-only permissions
      writeToLogFile(@"[INFO] Immutable flag failed, trying read-only permissions");
      if (setFileReadOnly(destFilePath)) {
        writeToLogFile(@"[INFO] Successfully set read-only permissions on database file");
      } else {
        writeToLogFile(@"[WARN] Failed to set file permissions, relying on monitoring only");
      }
    }
    
    // Log the final protection status
    if (isFileProtected(destFilePath)) {
      writeToLogFile(@"[INFO] Database file is now protected from overwriting");
    } else {
      writeToLogFile(@"[WARN] Database file protection failed, relying on monitoring");
    }
    
    // Setup file monitoring as backup
    setupFileMonitoring(databasePath, destFilePath);
  }
} 