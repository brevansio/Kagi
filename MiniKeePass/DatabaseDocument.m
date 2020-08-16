/*
 * Copyright 2011-2012 Jason Rush and John Flanagan. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "DatabaseDocument.h"
#import "AppSettings.h"

@interface DatabaseDocument ()
@property (nonatomic, strong) KdbPassword *kdbPassword;
@end

@implementation DatabaseDocument

- (id)initWithURL:(NSURL *)url password:(NSString *)password keyFile:(NSURL *)keyFile {
    self = [super initWithFileURL:url];
    if (self) {
        if (password == nil && keyFile == nil) {
            @throw [NSException exceptionWithName:@"IllegalArgument"
                                           reason:NSLocalizedString(@"No password or keyfile specified", nil)
                                         userInfo:nil];
        }

        self.filename = url.lastPathComponent;
        self.url = url;

        NSStringEncoding passwordEncoding = [[AppSettings sharedInstance] passwordEncoding];
        self.kdbPassword = [[KdbPassword alloc] initWithPassword:password
                                                passwordEncoding:passwordEncoding
                                                         keyFile:keyFile];

        self.kdbTree = [KdbReaderFactory load:url.path withPassword:self.kdbPassword];
    }
    return self;
}

- (void)save {
    [KdbWriterFactory persist:self.kdbTree file:self.fileURL withPassword:self.kdbPassword];
}

+ (void)searchGroup:(KdbGroup *)group searchText:(NSString *)searchText results:(NSMutableArray *)results {
    for (KdbEntry *entry in group.entries) {
        if ([self matchesEntry:entry searchText:searchText]) {
            [results addObject:entry];
        }
    }

    for (KdbGroup *g in group.groups) {
        if (![g.name isEqualToString:@"Backup"] && ![g.name isEqualToString:NSLocalizedString(@"Backup", nil)]) {
            [self searchGroup:g searchText:searchText results:results];
        }
    }
}

+ (BOOL)matchesEntry:(KdbEntry *)entry searchText:(NSString *)searchText {
    BOOL searchTitleOnly = [[AppSettings sharedInstance] searchTitleOnly];

    if ([entry.title rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0) {
        return YES;
    }
    if (!searchTitleOnly) {
        if ([entry.username rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0) {
            return YES;
        }
        if ([entry.url rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0) {
            return YES;
        }
        if ([entry.notes rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0) {
            return YES;
        }
    }
    return NO;
}

@end
