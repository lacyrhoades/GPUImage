#import "GPUImageImageStream.h"

@interface GPUImageImageStream ()
{
    UIImage *_image;
    CMTime time;
    NSTimeInterval actualTimeOfLastUpdate;
}

@end

@implementation GPUImageImageStream

- (void)updateImage: (UIImage *)image {
    _image = image;
    [self update];
}

- (CGSize)sizeInPixels;
{
    CGSize pointSize = _image.size;
    return CGSizeMake(_image.scale * pointSize.width, _image.scale * pointSize.height);
}

- (void)update;
{
    [self updateWithTimestamp:kCMTimeIndefinite];
}

- (void)updateUsingCurrentTime;
{
    if (CMTIME_IS_INVALID(time)) {
        time = CMTimeMakeWithSeconds(0, 600);
        actualTimeOfLastUpdate = [NSDate timeIntervalSinceReferenceDate];
    } else {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        NSTimeInterval diff = now - actualTimeOfLastUpdate;
        time = CMTimeAdd(time, CMTimeMakeWithSeconds(diff, 600));
        actualTimeOfLastUpdate = now;
    }

    [self updateWithTimestamp:time];
}

- (void)updateWithTimestamp:(CMTime)frameTime;
{
    [GPUImageContext useImageProcessingContext];
    
    CGSize layerPixelSize = [self sizeInPixels];
    
    CGRect fullRect = CGRectMake(0, 0, layerPixelSize.width, layerPixelSize.height);
    
    GLubyte *imageData = (GLubyte *) calloc(1, (int)layerPixelSize.width * (int)layerPixelSize.height * 4);
    
    CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();    
    
    CGContextRef imageContext = CGBitmapContextCreate(imageData, (int)layerPixelSize.width, (int)layerPixelSize.height, 8, (int)layerPixelSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

    CGContextScaleCTM(imageContext, _image.scale, _image.scale);
    
    CGContextDrawImage(imageContext, fullRect, _image.CGImage);
    
    CGContextRelease(imageContext);
    
    CGColorSpaceRelease(genericRGBColorspace);
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:layerPixelSize textureOptions:self.outputTextureOptions onlyTexture:YES];

    glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)layerPixelSize.width, (int)layerPixelSize.height, 0, GL_BGRA, GL_UNSIGNED_BYTE, imageData);
    
    free(imageData);
    
    for (id<GPUImageInput> currentTarget in targets)
    {
        if (currentTarget != self.targetToIgnoreForUpdates)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [currentTarget setInputSize:layerPixelSize atIndex:textureIndexOfTarget];
            [currentTarget newFrameReadyAtTime:frameTime atIndex:textureIndexOfTarget];
        }
    }    
}

@end
