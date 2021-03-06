//
//  MainViewController.m
//  Rezzo
//
//  Created by Rego on 5/16/13.
//  Copyright (c) 2013 Regaip Sen. All rights reserved.
//

#import "MainViewController.h"
#import "DescriptionViewController.h"
#import "Brain.h"
#import <MobileCoreServices/MobileCoreServices.h>

#import <AssetsLibrary/ALAsset.h>
#import <AssetsLibrary/ALAssetRepresentation.h>
#import <ImageIO/CGImageSource.h>
#import <ImageIO/CGImageProperties.h>
#import <ImageIO/CGImageDestination.h>

@interface MainViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UploadControllerDelegate>

@property (nonatomic, strong) CLLocationManager* locationManager;
@property (nonatomic, weak) DescriptionViewController* dvc;

@property (nonatomic, strong) UIAlertView *alertView;
@property (nonatomic, strong) UIActivityIndicatorView* spinner;

@end


@implementation MainViewController

#pragma mark - UI callbacks

- (void) viewWillAppear:(BOOL)animated {
    [self.tableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// add top bar button items
    
    UIBarButtonItem *uploadButton          = [[UIBarButtonItem alloc]
                                           initWithTitle:@"Upload" style:UIBarButtonItemStylePlain
                                           target:self action:@selector(uploadPhotos:)];
    
    UIBarButtonItem *mapButton          = [[UIBarButtonItem alloc]
                                            initWithTitle:@"Map" style:UIBarButtonItemStylePlain 
                                            target:self action:@selector(mapPhotos:)];
    
    UIBarButtonItem *cameraButton          = [[UIBarButtonItem alloc]
                                           initWithBarButtonSystemItem:UIBarButtonSystemItemCamera
                                           target:self action:@selector(addImageFromCamera:)];
    
    UIBarButtonItem *addButton          = [[UIBarButtonItem alloc]
                                           initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                           target:self action:@selector(addImageFromLibrary:)];
    
    self.navigationItem.leftBarButtonItems =
    [NSArray arrayWithObjects:uploadButton, mapButton, nil];
    
    self.navigationItem.rightBarButtonItems =
    [NSArray arrayWithObjects:addButton, cameraButton, nil];
    
    // init locationManager (for camera uploads)
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters; // 100 m
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"Detail"])
    {
        UITabBarController* tbc = segue.destinationViewController;
        self.dvc = tbc.childViewControllers[0];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - top bar button helpers

- (UIActivityIndicatorView*) startSpinner:(UIView*)view
{
    UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    CGRect frame = spinner.frame;
    frame.origin.x = view.bounds.size.width / 2 - frame.size.width / 2;
    frame.origin.y = view.bounds.size.height / 2 - frame.size.height / 2;
    frame.origin.y += 10; // make room for title
    spinner.frame = frame;
    [view addSubview:spinner];
    [spinner startAnimating];
    return spinner;
}

- (void)uploadPhotos:(id)sender
{
    if ([[Brain get] photos].count == 0)
    {
        // no photos available; pop up alert
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"No pictures available yet" message:@"Please add entries from album or camera before uploading." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        
        [alertView show];
    }
    else
    {
        self.alertView = [[UIAlertView alloc] initWithTitle:@"Uploading..." message:@"" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil, nil];
        
        [self.alertView show];
        self.spinner = [self startSpinner:self.alertView];
        
        [Brain uploadPhotos:self];
    }
}

- (void) doneUploading:(BOOL)success errorMessage:(NSString*)message
{
    [self.spinner stopAnimating];
    [self.spinner removeFromSuperview];
    [self.alertView dismissWithClickedButtonIndex:0 animated:YES];
    
    if (success)
    {
        [self.tableView reloadData];
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Upload failed" message:[NSString stringWithFormat: @"Problem uploading to server.  Please try again later.\n%@", message] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        
        [alertView show];
    }
}

- (void)mapPhotos:(id)sender
{
    [Brain deselectPhoto];
    [self performSegueWithIdentifier:@"Map Photos" sender:self];
}

#pragma mark - Image Picker goodies

- (void)addImageFromSource:(UIImagePickerControllerSourceType)sourceType {
    if ([UIImagePickerController isSourceTypeAvailable:sourceType]) {
        NSArray *mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:sourceType];
        if ([mediaTypes containsObject:(NSString *)kUTTypeImage]) {
            UIImagePickerController *picker = [[UIImagePickerController alloc] init];
            picker.delegate = self;
            picker.sourceType = sourceType;
            picker.mediaTypes = [NSArray arrayWithObject:(NSString *)kUTTypeImage];
            picker.allowsEditing = YES;
            [self presentViewController:picker animated:YES completion:nil];
        }
    }
}

- (void)addImageFromCamera:(UIBarButtonItem *)sender {
    [self.locationManager startUpdatingLocation];
    [self addImageFromSource:UIImagePickerControllerSourceTypeCamera];
    [self.locationManager stopUpdatingLocation];
}

- (void)addImageFromLibrary:(UIBarButtonItem *)sender {
    [self addImageFromSource:UIImagePickerControllerSourceTypePhotoLibrary];
}

- (void)dismissImagePicker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    if (!image) image = [info objectForKey:UIImagePickerControllerOriginalImage];
    if (image) {
        
        // HACK: direct camera images don't have GPS data in their metadata
        // so we have to use locationManager instead
        if (picker.sourceType == UIImagePickerControllerSourceTypeCamera)
        {
            
            PhotoInfo* newPhoto = [[PhotoInfo alloc] init];
            newPhoto.image = image;
            newPhoto.location = self.locationManager.location.coordinate;
            [Brain addAndSelectPhoto:newPhoto];
            [self performSegueWithIdentifier:@"Detail" sender:self];
            [self dismissImagePicker];
            return;
        }
        
        // following block posted by moosgummi on stackoverflow: extract GPS data from image metadata
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library assetForURL:[info objectForKey:UIImagePickerControllerReferenceURL]
                 resultBlock:^(ALAsset *asset) {
                     
                     ALAssetRepresentation *image_representation = [asset defaultRepresentation];
                     
                     // create a buffer to hold image data
                     uint8_t *buffer = (Byte*)malloc(image_representation.size);
                     NSUInteger length = [image_representation getBytes:buffer fromOffset: 0.0  length:image_representation.size error:nil];
                     
                     if (length != 0)  {
                         
                         // buffer -> NSData object; free buffer afterwards
                         NSData *adata = [[NSData alloc] initWithBytesNoCopy:buffer length:image_representation.size freeWhenDone:YES];
                         
                         // identify image type (jpeg, png, RAW file, ...) using UTI hint
                         NSDictionary* sourceOptionsDict = [NSDictionary dictionaryWithObjectsAndKeys:(id)[image_representation UTI] ,kCGImageSourceTypeIdentifierHint,nil];
                         
                         // create CGImageSource with NSData
                         CGImageSourceRef sourceRef = CGImageSourceCreateWithData((__bridge CFDataRef) adata,  (__bridge CFDictionaryRef) sourceOptionsDict);
                         
                         // get imagePropertiesDictionary
                         CFDictionaryRef imagePropertiesDictionary;
                         imagePropertiesDictionary = CGImageSourceCopyPropertiesAtIndex(sourceRef,0, NULL);
                         
                         // get exif data
                         CFDictionaryRef gpsRef = (CFDictionaryRef)CFDictionaryGetValue(imagePropertiesDictionary, kCGImagePropertyGPSDictionary);
                         NSDictionary *gps_dict = (__bridge NSDictionary*)gpsRef;
                         PhotoInfo* newPhoto = [[PhotoInfo alloc] init];
                         newPhoto.image = image;
                         CLLocationCoordinate2D location;
                         
                         location.latitude = [[gps_dict objectForKey:@"Latitude"] doubleValue];
                         if ([[gps_dict objectForKey:@"LatitudeRef"] isEqualToString:@"S"])
                         {
                             location.latitude = -location.latitude;
                         }
                         location.longitude = [[gps_dict objectForKey:@"Longitude"] doubleValue];
                         if ([[gps_dict objectForKey:@"LongitudeRef"] isEqualToString:@"W"])
                         {
                             location.longitude = -location.longitude;
                         }
                         newPhoto.location = location;
                         [Brain addAndSelectPhoto:newPhoto];
                         [self performSegueWithIdentifier:@"Detail" sender:self];
                         
                         CFRelease(imagePropertiesDictionary);
                         CFRelease(sourceRef);
                     }
                     else {
                         NSLog(@"image_representation buffer length == 0");
                     }
                 }
                failureBlock:^(NSError *error) {
                    NSLog(@"couldn't get asset: %@", error);
                }
         ];
        
    }
    [self dismissImagePicker];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissImagePicker];
}

#pragma mark - Table View callbacks

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[[Brain get] photos] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Picture";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    PhotoInfo* photoInfo = [[[Brain get] photos] objectAtIndex:indexPath.row];
    
    cell.textLabel.text = photoInfo.title;
    cell.detailTextLabel.text = photoInfo.categoryString;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id photo = [[[Brain get] photos] objectAtIndex:indexPath.row];
    [Brain selectPhoto:photo];
    [self.dvc updateView];
}

@end
