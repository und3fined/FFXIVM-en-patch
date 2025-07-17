#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Function to fix dialogue issues by copying database file
void dialogueFix(void);

// Helper function to write to log file
void writeToLogFile(NSString *message);

// File permission management functions
BOOL setFileReadOnly(NSString *filePath);
BOOL restoreFileWritePermissions(NSString *filePath);
BOOL setFileImmutable(NSString *filePath);
BOOL removeFileImmutable(NSString *filePath);
BOOL isFileProtected(NSString *filePath); 