//
//  ALTestingViewController.m
//  ALNinePatchImage
//
//  Created by Alex Lee on 9/22/14.
//  Copyright (c) 2014 Alex Lee. All rights reserved.
//

#import "ALTestingViewController.h"
#import "UIImage+NinePatch.h"

@interface ALTestingViewController ()

@end

@implementation ALTestingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIScrollView *contentView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:contentView];
    
    CGRect frame = CGRectMake(20, 50, CGRectGetWidth(self.view.bounds) - 40, 60);
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = @"popup_bg.9@2x.png (vertical & horizontal resizeable) original image:";
    label.numberOfLines = 0;
    [contentView addSubview:label];
    
    frame.origin.y += frame.size.height;
    UIImage *image = [UIImage imageNamed:@"popup_bg.9"];
    //[image fixImageColor];
    UIImageView *popupOrigin = [[UIImageView alloc]initWithImage:image];
    
    frame.size = popupOrigin.bounds.size;
    popupOrigin.frame = frame;
    [contentView addSubview:popupOrigin];
    
    
    
    
    frame.origin.y += frame.size.height + 20;
    frame.size = CGSizeMake(CGRectGetWidth(self.view.bounds), 20);
    label = [[UILabel alloc] initWithFrame:frame];
    label.text = @"resize: 50x50";
    [contentView addSubview:label];
    
    frame.origin.y += frame.size.height;
    frame.size = CGSizeMake(50, 50);
    UIImageView *popup1 = [[UIImageView alloc]initWithFrame:frame];
    popup1.image = [UIImage ninePatchImageNamed:@"popup_bg"];
    [contentView addSubview:popup1];
    
    
    frame.origin.y += frame.size.height + 20;
    frame.size = CGSizeMake(CGRectGetWidth(self.view.bounds), 20);
    label = [[UILabel alloc] initWithFrame:frame];
    label.text = @"resize: 280x150";
    [contentView addSubview:label];
    
    frame.origin.y += frame.size.height;
    frame.size = CGSizeMake(280, 150);
    UIImageView *popup2 = [[UIImageView alloc] initWithFrame:frame];
    popup2.image = [UIImage ninePatchImageNamed:@"popup_bg"];
    [contentView addSubview:popup2];
    
    
    
    frame.origin.y += frame.size.height + 20;
    frame.size = CGSizeMake(CGRectGetWidth(self.view.bounds) - 40, 60);
    label = [[UILabel alloc] initWithFrame:frame];
    label.text = @"bar_bg.9.png (horizontal resizeable) original image:";
    label.numberOfLines = 0;
    [contentView addSubview:label];
    
    frame.origin.y += frame.size.height;
    popupOrigin = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"bar_bg.9"]];
    frame.size = popupOrigin.bounds.size;
    popupOrigin.frame = frame;
    [contentView addSubview:popupOrigin];
    
    
    
    frame.origin.y += frame.size.height + 20;
    frame.size = CGSizeMake(CGRectGetWidth(self.view.bounds), 20);
    label = [[UILabel alloc] initWithFrame:frame];
    label.text = @"resize: 50x41";
    [contentView addSubview:label];
    
    frame.origin.y += frame.size.height;
    frame.size = CGSizeMake(50, 41);
    popup1 = [[UIImageView alloc]initWithFrame:frame];
    popup1.image = [UIImage ninePatchImageNamed:@"bar_bg"];
    [contentView addSubview:popup1];
    
    
    frame.origin.y += frame.size.height + 20;
    frame.size = CGSizeMake(CGRectGetWidth(self.view.bounds), 20);
    label = [[UILabel alloc] initWithFrame:frame];
    label.text = @"resize: 280x41";
    [contentView addSubview:label];
    
    frame.origin.y += frame.size.height;
    frame.size = CGSizeMake(280, 41);
    popup2 = [[UIImageView alloc] initWithFrame:frame];
    popup2.image = [UIImage ninePatchImageNamed:@"bar_bg"];
    [contentView addSubview:popup2];
    
    
    contentView.contentSize = CGSizeMake(self.view.bounds.size.width, frame.origin.y + frame.size.height);
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
