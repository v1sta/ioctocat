#import "GHCommit.h"
#import "GHUser.h"
#import "GHFiles.h"
#import "GHRepository.h"
#import "GHRepoComments.h"
#import "iOctocat.h"
#import "NSString+Extensions.h"
#import "NSDictionary+Extensions.h"


@implementation GHCommit

- (id)initWithRepository:(GHRepository *)repo andCommitID:(NSString *)commitID {
	self = [super init];
	if (self) {
		self.repository = repo;
		self.commitID = commitID;
		self.resourcePath = [NSString stringWithFormat:kRepoCommitFormat, self.repository.owner, self.repository.name, self.commitID];
	}
	return self;
}

- (void)setValues:(id)dict {
	// users
	NSDictionary *authorDict = [dict safeDictForKey:@"author"];
	NSDictionary *committerDict = [dict safeDictForKey:@"committer"];
	if (!authorDict) authorDict = [dict safeDictForKeyPath:@"commit.author"];
	if (!committerDict) committerDict = [dict safeDictForKeyPath:@"commit.committer"];
	NSString *authorLogin = [authorDict safeStringForKey:@"login"];
	NSString *committerLogin = [committerDict safeStringForKey:@"login"];
	if (!authorLogin.isEmpty) {
		self.author = [[iOctocat sharedInstance] userWithLogin:authorLogin];
		if (self.author.isUnloaded) [self.author setValues:authorDict];
	}
	if (!committerLogin.isEmpty) {
		self.committer = [[iOctocat sharedInstance] userWithLogin:committerLogin];
		if (self.committer.isUnloaded) [self.committer setValues:committerDict];
	}
	// info
	self.authorEmail = [authorDict safeStringForKey:@"email"];
	self.authorName = [authorDict safeStringForKey:@"name"];
	self.authoredDate = [dict safeDateForKeyPath:@"commit.author.date"];
	self.committedDate = [dict safeDateForKeyPath:@"commit.committer.date"];
	self.message = [dict safeStringForKeyPath:@"commit.message"];
	if (self.message.isEmpty) self.message = [dict safeStringForKey:@"message"];
	// files
	self.added = [[GHFiles alloc] init];
	self.removed = [[GHFiles alloc] init];
	self.modified = [[GHFiles alloc] init];
	NSArray *files = [dict safeArrayForKey:@"files"];
	for (NSDictionary *file in files) {
		NSString *status = [file safeStringForKey:@"status"];
		if ([status isEqualToString:@"removed"]) {
			[self.removed addObject:file];
		} else if ([status isEqualToString:@"added"]) {
			[self.added addObject:file];
		} else {
			[self.modified addObject:file];
		}
	}
	[self.added markAsLoaded];
	[self.removed markAsLoaded];
	[self.modified markAsLoaded];
}

- (GHRepoComments *)comments {
    if (!_comments) {
        _comments = [[GHRepoComments alloc] initWithRepo:self.repository andCommitID:self.commitID];
    }
    return _comments;
}

- (NSString *)shortenedSha {
    return [self.commitID substringToIndex:7];
}

- (NSString *)shortenedMessage {
	return [self.message componentsSeparatedByString:@"\n"][0];
}

- (NSString *)extendedMessage {
	int loc = [self.message rangeOfString:@"\n"].location;
	NSCharacterSet *trimSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSString *ext = [self.message substringFromIndex:loc];
	return [ext stringByTrimmingCharactersInSet:trimSet];
}

- (BOOL)hasExtendedMessage {
	return [self.message rangeOfString:@"\n"].location != NSNotFound;
}

@end
