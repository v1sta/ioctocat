#import "IOCCommitsController.h"
#import "IOCCommitController.h"
#import "IOCCommitCell.h"
#import "GHCommits.h"
#import "GHCommit.h"
#import "iOctocat.h"
#import "NSString+Extensions.h"
#import "IOCResourceStatusCell.h"
#import "SVProgressHUD.h"


@interface CopyMenuItem : UIMenuItem
@property(nonatomic,strong)NSIndexPath *indexPath;
@end


@implementation CopyMenuItem
@end


@interface IOCCommitsController ()
@property(nonatomic,strong)GHCommits *commits;
@property(nonatomic,strong)IOCResourceStatusCell *statusCell;
@end


@implementation IOCCommitsController

- (id)initWithCommits:(GHCommits *)commits {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		self.commits = commits;
	}
	return self;
}

#pragma mark View Events

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.title = self.title ? self.title : @"Commits";
	if (!self.commits.resourcePath.isEmpty) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
	}
	self.statusCell = [[IOCResourceStatusCell alloc] initWithResource:self.commits name:@"commits"];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.commits.isUnloaded) {
		[self.commits loadWithSuccess:^(GHResource *instance, id data) {
			[self.tableView reloadData];
		}];
	} else if (self.commits.isChanged) {
		[self.tableView reloadData];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[SVProgressHUD dismiss];
}

#pragma mark Actions

- (IBAction)refresh:(id)sender {
	if (self.commits.isLoading) return;
	[self.commits loadWithParams:nil start:^(GHResource *instance) {
		instance.isEmpty ? [self.tableView reloadData] : [SVProgressHUD showWithStatus:@"Reloading"];
	} success:^(GHResource *instance, id data) {
		[SVProgressHUD dismiss];
		[self.tableView reloadData];
	} failure:^(GHResource *instance, NSError *error) {
		instance.isEmpty ? [self.tableView reloadData] : [SVProgressHUD showErrorWithStatus:@"Reloading failed"];
	}];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)longPressRecognizer {
    if (longPressRecognizer.state == UIGestureRecognizerStateBegan) {
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[longPressRecognizer locationInView:self.tableView]];
        if (indexPath && indexPath.row != NSNotFound && indexPath.section != NSNotFound) {
            CopyMenuItem *menuItem = [[CopyMenuItem alloc] initWithTitle:@"Copy" action:@selector(copyMenuButtonPressed:)];
            menuItem.indexPath = indexPath;
            [UIMenuController sharedMenuController].menuItems = @[menuItem];
            [[UIMenuController sharedMenuController] setTargetRect:[self.tableView rectForRowAtIndexPath:indexPath] inView:self.tableView];
            [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
        }
    }
}

- (void)copyMenuButtonPressed:(UIMenuController *)menuController {
    CopyMenuItem *menuItem = menuController.menuItems[0];
    if (menuItem.indexPath) {
        GHCommit *commit = self.commits[menuItem.indexPath.row];
        [UIPasteboard generalPasteboard].string = commit.shortenedSha;
    }
}

#pragma mark TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.commits.isEmpty ? 1 : self.commits.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.commits.isEmpty) return self.statusCell;
	IOCCommitCell *cell = [tableView dequeueReusableCellWithIdentifier:kCommitCellIdentifier];
    if (cell == nil) {
        cell = [IOCCommitCell cell];
        UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [cell addGestureRecognizer:longPressRecognizer];
    }
	cell.commit = self.commits[indexPath.row];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.commits.isEmpty) return;
	GHCommit *commit = self.commits[indexPath.row];
	IOCCommitController *viewController = [[IOCCommitController alloc] initWithCommit:commit];
	[self.navigationController pushViewController:viewController animated:YES];
}

#pragma mark Responder

- (BOOL)canBecomeFirstResponder {
    return YES;
}

@end