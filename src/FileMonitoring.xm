#import "FileMonitoring.h"
#import "DialogueFix.h"

// Global variables for file monitoring
NSString *g_databaseSourcePath = nil;
NSString *g_databaseDestPath = nil;
NSTimer *g_fileMonitorTimer = nil;
NSData *g_originalFileData = nil;

// Helper function to compare file contents
BOOL filesAreIdentical(NSString *path1, NSString *path2) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  if (![fileManager fileExistsAtPath:path1] || ![fileManager fileExistsAtPath:path2]) {
    return NO;
  }
  
  NSData *data1 = [NSData dataWithContentsOfFile:path1];
  NSData *data2 = [NSData dataWithContentsOfFile:path2];
  
  if (!data1 || !data2) {
    return NO;
  }
  
  return [data1 isEqualToData:data2];
}

// Function to restore the database file if it's been overwritten
void restoreDatabaseFile() {
  if (!g_databaseSourcePath || !g_databaseDestPath) {
    return;
  }
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  
  // Check if the destination file exists and if it's different from our source
  if ([fileManager fileExistsAtPath:g_databaseDestPath]) {
    if (filesAreIdentical(g_databaseSourcePath, g_databaseDestPath)) {
      // File is correct, no need to restore
      return;
    }
    
    // File has been overwritten, restore it
    writeToLogFile(@"[MONITOR] Database file was overwritten, restoring...");
    
    NSError *error = nil;
    if ([fileManager removeItemAtPath:g_databaseDestPath error:&error]) {
      if ([fileManager copyItemAtPath:g_databaseSourcePath toPath:g_databaseDestPath error:&error]) {
        writeToLogFile(@"[MONITOR] Successfully restored database file");
      } else {
        writeToLogFile([NSString stringWithFormat:@"[MONITOR] Failed to copy restored database: %@", error.localizedDescription]);
      }
    } else {
      writeToLogFile([NSString stringWithFormat:@"[MONITOR] Failed to remove overwritten database: %@", error.localizedDescription]);
    }
  } else {
    // File doesn't exist at all, restore it
    writeToLogFile(@"[MONITOR] Database file missing, restoring...");
    
    NSError *error = nil;
    if ([fileManager copyItemAtPath:g_databaseSourcePath toPath:g_databaseDestPath error:&error]) {
      writeToLogFile(@"[MONITOR] Successfully restored missing database file");
    } else {
      writeToLogFile([NSString stringWithFormat:@"[MONITOR] Failed to restore missing database: %@", error.localizedDescription]);
    }
  }
}

// Start monitoring the database file
void startDatabaseMonitoring() {
  if (g_fileMonitorTimer) {
    [g_fileMonitorTimer invalidate];
  }
  
  // Use a dispatch timer for better reliability
  static dispatch_source_t timer = nil;
  if (timer) {
    dispatch_source_cancel(timer);
  }
  
  timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
  if (timer) {
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), 5.0 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
      restoreDatabaseFile();
    });
    dispatch_resume(timer);
    writeToLogFile(@"[MONITOR] Started database file monitoring (5 second intervals)");
  } else {
    writeToLogFile(@"[MONITOR] Failed to create monitoring timer");
  }
}

// Stop monitoring (cleanup)
void stopDatabaseMonitoring() {
  if (g_fileMonitorTimer) {
    [g_fileMonitorTimer invalidate];
    g_fileMonitorTimer = nil;
    writeToLogFile(@"[MONITOR] Stopped database file monitoring");
  }
}

// Manual restore function - can be called anytime
void manualRestoreDatabase() {
  writeToLogFile(@"[MANUAL] Manual database restore requested");
  restoreDatabaseFile();
}

// Check if monitoring is active
BOOL isDatabaseMonitoringActive() {
  return (g_databaseSourcePath != nil && g_databaseDestPath != nil);
}

// Setup function to initialize monitoring with paths
void setupFileMonitoring(NSString *sourcePath, NSString *destPath) {
  // Store paths for monitoring
  g_databaseSourcePath = [sourcePath copy];
  g_databaseDestPath = [destPath copy];
  
  writeToLogFile([NSString stringWithFormat:@"[MONITOR] Setup file monitoring from %@ to %@", sourcePath, destPath]);
  
  // Start monitoring
  startDatabaseMonitoring();
}

// App lifecycle functions
void setupAppLifecycleMonitoring() {
  // Use string literals as fallback in case UIKit constants aren't available
  NSString *didBecomeActiveNotification = @"UIApplicationDidBecomeActiveNotification";
  NSString *willEnterForegroundNotification = @"UIApplicationWillEnterForegroundNotification";
  NSString *didEnterBackgroundNotification = @"UIApplicationDidEnterBackgroundNotification";
  
  [[NSNotificationCenter defaultCenter] addObserverForName:didBecomeActiveNotification
                                                    object:nil
                                                     queue:[NSOperationQueue mainQueue]
                                                usingBlock:^(NSNotification *note) {
    writeToLogFile(@"[LIFECYCLE] App became active, checking database integrity");
    if (g_databaseSourcePath && g_databaseDestPath) {
      restoreDatabaseFile();
    }
  }];
  
  [[NSNotificationCenter defaultCenter] addObserverForName:willEnterForegroundNotification
                                                    object:nil
                                                     queue:[NSOperationQueue mainQueue]
                                                usingBlock:^(NSNotification *note) {
    writeToLogFile(@"[LIFECYCLE] App entering foreground, restarting monitoring");
    if (g_databaseSourcePath && g_databaseDestPath) {
      startDatabaseMonitoring();
    }
  }];
  
  [[NSNotificationCenter defaultCenter] addObserverForName:didEnterBackgroundNotification
                                                    object:nil
                                                     queue:[NSOperationQueue mainQueue]
                                                usingBlock:^(NSNotification *note) {
    writeToLogFile(@"[LIFECYCLE] App entering background, monitoring continues");
    // Keep monitoring active even in background
  }];
  
  writeToLogFile(@"[MONITOR] App lifecycle monitoring setup complete");
} 