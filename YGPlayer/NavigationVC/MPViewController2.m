//
//  MPViewController.m
//  YGPlayer
//
//  Created by Jackson on 2018/5/11.
//  Copyright © 2018年 Jackson. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>
#import "MPViewController2.h"

@interface MPViewController2 ()
@property(nonatomic,strong) MPMoviePlayerController * MPPlayer;
@end

@implementation MPViewController2

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationMPPlayer:) name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
    
    _MPPlayer=[[MPMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:@"http://127.0.0.1:10086/20184k.m4v"]];
    _MPPlayer.view.frame=self.view.bounds;
    [self.view addSubview:_MPPlayer.view];
    _MPPlayer.fullscreen=YES;
    _MPPlayer.controlStyle=MPMovieControlStyleEmbedded;
    [_MPPlayer play];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = NO;
    [_MPPlayer pause];
}
#pragma mark -
- (void)notificationMPPlayer:(NSNotification*)noti
{
    [self dismissViewControllerAnimated:NO completion:nil];
}

@end
