//
//  WMPlayerViewController.m
//  CHPlayer
//
//  Created by Jackson on 2018/5/10.
//  Copyright © 2018年 Hxc. All rights reserved.
//

#import "WMPlayerViewController.h"
#import "WMPlayer.h"

@interface WMPlayerViewController ()
{
    WMPlayer *mp;
}
@end

@implementation WMPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupPlayer];
    
}
#pragma mark -
-(void)setupPlayer
{
    mp=[WMPlayer new];
    mp.frame=self.view.frame;
    mp.URLString=@"http://127.0.0.1:10086/20184k.m4v";
    [self.view addSubview:mp];
    [mp play];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = NO;
    [mp pause];
}

@end
