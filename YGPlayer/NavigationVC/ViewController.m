//
//  ViewController.m
//  CHPlayer
//
//  Created by Cher on 16/6/12.
//  Copyright © 2016年 Hxc. All rights reserved.
//
#import <AVKit/AVKit.h>
#import "ViewController.h"
#import "Masonry.h"
#import "VideoPlayerViewController.h"
#import "VideoModel.h"
#import "PlayOnFullScreenViewController.h"
#import "WMPlayerViewController.h"
#import "ZFPlayerViewController.h"
#import "MPViewController2.h"
#import <MediaPlayer/MediaPlayer.h>
#import "IJKDemoLocalFolderViewController.h"
#import "HYFileManager.h"
#import <AVKit/AVKit.h>



@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>

@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) NSMutableArray *tableData;


@end

@implementation ViewController

- (void)viewDidLoad {
     [super viewDidLoad];
     // Do any additional setup after loading the view, typically from a nib.
     
     UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
     [self.view addSubview:tableView];
     
     tableView.backgroundColor = [UIColor whiteColor];
     tableView.backgroundView = nil;
     tableView.delegate = self;
     tableView.scrollsToTop = YES;
     tableView.dataSource = self;
     tableView.rowHeight = 60;
     [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
     self.tableView = tableView;
     [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
          make.top.equalTo(@(64));
          make.left.right.bottom.equalTo(self.view);
     }];
     
     NSArray *titles = @[@"爱奇艺,芒果,优酷播放器(无导航栏)",@"带导航栏",@"全屏",@"WMPlayer",@"ZFPlayer",@"MPMoviePlayer",@"AVPlayer",@"本地视频"];
     NSArray *type   = @[@(PlayerTypeOfNoNavigationBar),@(PlayerTypeOfNavigationBar),@(PlayerTypeOfFullScreen),@(WMPlayer),@(ZFPlayer),@(MPMoviePlayer),@(AVPlayerVC),@(LocalFolder)];
     NSMutableArray *datas = [NSMutableArray arrayWithCapacity:titles.count];
     [titles enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
          VideoModel *model = [VideoModel new];
          model.title = obj;
          model.type  = [type[idx] integerValue];
          [datas addObject:model];
     }];
     self.tableData = datas;
}

#pragma mark === tableView delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
     return self.tableData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
     UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
     VideoModel *model   = self.tableData[indexPath.row];
     cell.textLabel.text = model.title;
     return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
     VideoModel *model = self.tableData[indexPath.row];
     if (model.type == PlayerTypeOfFullScreen) {
          PlayOnFullScreenViewController *p = [PlayOnFullScreenViewController new];
          [self.navigationController pushViewController:p animated:YES];
          return;
     }
    
    if (model.type == WMPlayer) {
        WMPlayerViewController *p = [WMPlayerViewController new];
        [self.navigationController pushViewController:p animated:NO];
        return;
    }
    if (model.type == ZFPlayer) {
         ZFPlayerViewController *p = [ZFPlayerViewController new];
        [self.navigationController pushViewController:p animated:NO];
        return;
    }
    
    if (model.type == MPMoviePlayer) {
        // 设置资源路径
        NSURL *url = [NSURL URLWithString:@"http:/127.0.0.1:10086/20184k.m4v"];
        MPMoviePlayerViewController *p = [[MPMoviePlayerViewController alloc] initWithContentURL:url];
        
        [self presentViewController:p animated:NO completion:nil];
        return;
    }
    
    if (model.type == AVPlayerVC) {
       
        AVPlayerViewController *player = [AVPlayerViewController new];
        // 设置资源路径
        NSURL *url = [NSURL URLWithString:@"http:/127.0.0.1:10088/20184k.m4v"];
        // 控制器的player播放器
        player.player = [AVPlayer playerWithURL:url];
        // 试图的填充模式
        //player.videoGravity = AVLayerVideoGravityResizeAspect;
        // 是否显示播放控制条
        //player.showsPlaybackControls = YES;
        // 播放
        [player.player play];
        
        [self presentViewController:player animated:NO completion:nil];
        return;
    }
    if (model.type == LocalFolder) {
        IJKDemoLocalFolderViewController *l=[[IJKDemoLocalFolderViewController alloc] initWithFolderPath:[HYFileManager documentsDir] ];
         [self.navigationController pushViewController:l animated:YES];
        return;
        
    }
     VideoPlayerViewController *video = [VideoPlayerViewController new];
     video.type  = model.type;
     [self.navigationController pushViewController:video animated:YES];
     
}


- (IBAction)changeRootVCAction:(UIBarButtonItem *)sender {
     
     [[NSNotificationCenter defaultCenter] postNotificationName:@"CHANGEROOTVC" object:nil];

}

//设置是否支持自动旋转 默认开启
- (BOOL)shouldAutorotate{
     return YES;
}
// 支持旋转的方向
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
     return UIInterfaceOrientationMaskPortrait;
}

- (void)didReceiveMemoryWarning {
     [super didReceiveMemoryWarning];
     // Dispose of any resources that can be recreated.
}

@end
