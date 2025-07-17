#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Global variables for file monitoring (extern declarations)
extern NSString *g_databaseSourcePath;
extern NSString *g_databaseDestPath;
extern NSTimer *g_fileMonitorTimer;
extern NSData *g_originalFileData;

// File monitoring functions
BOOL filesAreIdentical(NSString *path1, NSString *path2);
void restoreDatabaseFile(void);
void startDatabaseMonitoring(void);
void stopDatabaseMonitoring(void);
void manualRestoreDatabase(void);
BOOL isDatabaseMonitoringActive(void);

// Setup function to initialize monitoring with paths
void setupFileMonitoring(NSString *sourcePath, NSString *destPath);

// App lifecycle monitoring setup
void setupAppLifecycleMonitoring(void); 